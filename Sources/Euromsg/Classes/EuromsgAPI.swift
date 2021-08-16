//
//  EuromsgAPI.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

protocol EMResponseProtocol: Decodable {}
class EMResponse: EMResponseProtocol {}

enum EuromsgAPIError: Error {
    case connectionFailed
}

protocol EuromsgAPIProtocol {
    func request(urlString: String)
    func request<R: EMRequestProtocol,
                 T: EMResponseProtocol>(requestModel: R,
                                        retry: Int,
                                        completion: @escaping (Result<T?, EuromsgAPIError>) -> Void)
}

class EuromsgAPI: EuromsgAPIProtocol {

    private let timeoutInterval = 30
    private let prodBaseUrl = ".euromsg.com"

    private var urlSession: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 3
        return URLSession.init(configuration: configuration)
    }

    func request(urlString: String) {
        guard let url = URL.init(string: urlString) else {
            EMLog.error("URL couldn't be initialized")
            return
        }
        let request = URLRequest.init(url: url)
        EMLog.info("Request to : \(url)")
        let dataTask = urlSession.dataTask(with: request) { _, _, error in
            guard let error = error else {
                EMLog.success("Request succesfully send to \(url)")
                return
            }
            EMLog.error("Server responded Error : \(error)")
        }
        dataTask.resume()
    }

    func request<R: EMRequestProtocol,
                 T: EMResponseProtocol>(requestModel: R,
                                        retry: Int,
                                        completion: @escaping (Result<T?, EuromsgAPIError>) -> Void) {

        guard let request = setupUrlRequest(requestModel) else {return}

        URLSession.shared.dataTask(with: request) {data, response, connectionError in
            if connectionError == nil {
                let remoteResponse = response as? HTTPURLResponse
                DispatchQueue.main.async {
                    if connectionError == nil &&
                        (remoteResponse?.statusCode == 200 || remoteResponse?.statusCode == 201) {
                        if let remoteResponse = remoteResponse {
                            EMLog.info("Server response code : \(remoteResponse.statusCode)")
                        }
                        guard let data = data else {
                            completion(.failure(EuromsgAPIError.connectionFailed))
                            if retry < 3 {
                                Euromsg.shared?.euromsgAPI?.request(requestModel: requestModel, retry: retry + 1, completion: completion)
                                
                            }
                            return
                            
                        }
                        EMLog.success("Server response with success : \(String(decoding: data, as: UTF8.self))")
                        let responseData = try? JSONDecoder().decode(T.self, from: data)
                        completion(.success(responseData))
                    } else {
                        completion(.failure(EuromsgAPIError.connectionFailed))
                        if retry < 3 {
                            Euromsg.shared?.euromsgAPI?.request(requestModel: requestModel, retry: retry + 1, completion: completion)
                            
                        }
                        if let remoteResponse = remoteResponse {
                            EMLog.error("Server response with failure : \(remoteResponse)")
                        }
                    }
                }
            } else {
                guard let connectionError = connectionError else {return}
                if retry < 3 {
                    Euromsg.shared?.euromsgAPI?.request(requestModel: requestModel, retry: retry + 1, completion: completion)
                    
                }
                EMLog.error("Connection error \(connectionError)")
            }
        }.resume()
    }

    func setupUrlRequest<R: EMRequestProtocol>(_ requestModel: R) -> URLRequest? {
        let urlString = "https://\(requestModel.subdomain)\(prodBaseUrl)/\(requestModel.path)"
        guard let url = URL.init(string: urlString) else {
            EMLog.info("URL couldn't be initialized")
            return nil
        }
        let userAgent = Euromsg.shared?.userAgent
        var request = URLRequest.init(url: url)
        request.httpMethod = requestModel.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue(userAgent, forHTTPHeaderField: EMKey.userAgent)
        request.timeoutInterval = TimeInterval(timeoutInterval)

        if requestModel.method == "POST" || requestModel.method == "PUT" {
            request.httpBody = try? JSONEncoder().encode(requestModel)
        }

        if let httpBody = request.httpBody {
            EMLog.info("""
                Request to \(url) with body
                \(String(data: httpBody, encoding: String.Encoding.utf8) ?? "")
                """)
        }
        return request
    }
}
