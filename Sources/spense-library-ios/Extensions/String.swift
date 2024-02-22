//
//  File.swift
//  
//
//  Created by Varun on 01/02/24.
//

extension String {
    func dynamicParams(with values: [String: String]) -> String {
        var result = self
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
