//
//  EuromsgTestAPI.swift
//  EuromsgTests
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation
@testable import Euromsg

class EuromsgAPIMock: EuromsgAPIProtocol {
    func request(urlString: String) {

    }
    func request<R: EMRequestProtocol,
                 T: EMResponseProtocol>(requestModel: R,
                                        completion: @escaping (Result<T?, EuromsgAPIError>) -> Void) {
    }
}
