import SwiftUI

struct AddAppView: View {
    @StateObject private var viewModel = AddAppViewModel()
    
    // Используем пустую строку для TextEditor
    @State private var inputText: String = ""
    
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Ссылки или ID (каждая с новой строки)")) {
                    // Заменяем TextField на TextEditor
                    TextEditor(text: $inputText)
                        .frame(height: 150)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: {
                        Task {
                            await viewModel.search(for: inputText)
                        }
                    }) {
                        // Меняем текст кнопки
                        Text("Найти все")
                    }
                    .disabled(inputText.isEmpty || viewModel.isLoading || viewModel.isSaving)
                }
                
                // --- Секция с результатом ---
                if viewModel.isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Поиск...")
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                } else if !viewModel.searchResults.isEmpty {
                    Section(header: Text("Найденные приложения (\(viewModel.searchResults.count))")) {
                        // Показываем список превью
                        List($viewModel.searchResults) { $result in // <<< Добавляем '$' для биндинга
                            VStack(alignment: .leading) {
                                HStack {
                                    AppPreviewView(appDetails: result.details)
                                    if result.isAlreadyAdded {
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                    }
                                }
                                
                                // НОВЫЙ TOGGLE
                                if !result.isAlreadyAdded {
                                    Toggle("Это моё приложение", isOn: Binding(
                                        get: { result.ownership == .mine },
                                        set: { isMine in
                                            result.ownership = isMine ? .mine : .competitor
                                        }
                                    ))
                                    .padding(.top, 8)
                                }
                            }
                        }
                    }
                    
                    Section {
                        if viewModel.isSaving {
                            ProgressView("Сохранение...", value: viewModel.saveProgress)
                        } else {
                            Button(action: {
                                Task {
                                    await viewModel.saveSelectedApps()
                                }
                            }) {
                                Text("Добавить все на трекинг")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.searchResults.allSatisfy { $0.isAlreadyAdded })
                        }
                    }
                }
            }
            .navigationTitle("Пакетное добавление")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .onChange(of: viewModel.didSaveApps) { _, didSave in
                if didSave {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    AddAppView()
}
