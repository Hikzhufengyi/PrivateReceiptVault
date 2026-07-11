import SwiftUI

struct CurrencyPicker: View {
    @Binding var currencyCode: String

    var body: some View {
        Picker("Currency", selection: $currencyCode) {
            ForEach(CurrencyOption.common) { option in
                Text(option.displayName)
                    .tag(option.code)
            }
        }
        .pickerStyle(.menu)
        .onAppear {
            if !CurrencyOption.common.contains(where: { $0.code == currencyCode }) {
                currencyCode = CurrencyOption.defaultCode
            }
        }
    }
}
