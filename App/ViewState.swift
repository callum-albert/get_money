import SwiftUI

/// SDK 27 的同名 State 宏需要额外编译插件；使用类型别名明确选择
/// 原生 State 属性包装器，兼容独立 swiftc 构建和 iOS 17。
typealias ViewState<Value> = SwiftUI.State<Value>
