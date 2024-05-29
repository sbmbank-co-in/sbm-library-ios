//
//  File.swift
//  
//
//  Created by Varun on 01/02/24.
//

struct ServiceNames {
    private static let HOST_URL = "\(EnvManager.hostName)/api"
    private static let USER_SLUG = "/user"
    private static var BANKING_SLUG = "/banking/{bank}"
    private static let GLOBAL_SLUG = "/global"
    private static var DEVICE_SLUG = "/device/{partner}"
    
    static let LOGIN = "\(HOST_URL)\(USER_SLUG)/token"
    static let LOGGED_IN = "\(HOST_URL)\(USER_SLUG)/logged_in"
    static var BANKING_ACCOUNTS_COUNT = "\(HOST_URL)\(BANKING_SLUG)/accounts/count"
    static var BANKING_CUSTOMER_CHECK = "\(HOST_URL)\(BANKING_SLUG)/customer/check"
    static let TIME = "\(HOST_URL)\(GLOBAL_SLUG)/time"
    static var DEVICE_BIND = "\(HOST_URL)\(DEVICE_SLUG)/bind"
    static var DEVICE_SESSION = "\(HOST_URL)\(DEVICE_SLUG)/session"
    static let NETWORK_KEYS = "\(HOST_URL)/network/keys"
}
