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

public enum EuromsgAPIError: Error {
    case connectionFailed
    case other(String)
}

protocol EuromsgAPIProtocol {
    func request<R: EMRequestProtocol,
                 T: EMResponseProtocol>(requestModel: R,
                                        retry: Int,
                                        completion: @escaping (Result<T?, EuromsgAPIError>) -> Void)
}

class EuromsgAPI: EuromsgAPIProtocol {
    
    private var urlSession: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 3
        return URLSession.init(configuration: configuration)
    }
    
    func request<R: EMRequestProtocol,
                 T: EMResponseProtocol>(requestModel: R,
                                        retry: Int,
                                        completion: @escaping (Result<T?, EuromsgAPIError>) -> Void) {
        
        guard let request = setupUrlRequest(requestModel) else {return}
        
        URLSession.shared.dataTask(with: request) { [weak self, retry] data, response, connectionError in
            if connectionError == nil {
                let remoteResponse = response as? HTTPURLResponse
                DispatchQueue.main.async {
                    if connectionError == nil &&
                        (remoteResponse?.statusCode == 200 || remoteResponse?.statusCode == 201) {
                        if let remoteResponse = remoteResponse {
                            EMLog.success("Server response success : \(remoteResponse.statusCode)")
                        }
                        var responseData: T? = nil
                        if let data = data {
                            responseData =  try? JSONDecoder().decode(T.self, from: data)
                        }
                        completion(.success(responseData))
                    } else {
                        EMLog.error("Server response with failure : \(String(describing: remoteResponse))")
                        if retry > 0 {
                            self?.request(requestModel: requestModel, retry: retry - 1, completion: completion)
                            
                        } else {
                            completion(.failure(EuromsgAPIError.connectionFailed))
                        }
                    }
                }
            } else {
                guard let connectionError = connectionError else {return}
                EMLog.error("Connection error \(connectionError)")
                if retry > 0 {
                    self?.request(requestModel: requestModel, retry: retry - 1, completion: completion)
                } else {
                    completion( .failure(EuromsgAPIError.connectionFailed))
                }
            }
        }.resume()
    }
    
    func setupUrlRequest<R: EMRequestProtocol>(_ requestModel: R) -> URLRequest? {
        let urlString = "https://\(requestModel.subdomain)\(requestModel.prodBaseUrl)/\(requestModel.path)"
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
        request.timeoutInterval = TimeInterval(EMKey.timeoutInterval)
        
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
