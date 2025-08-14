//
//  RecentProjectsListView.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 02/02/2023.
//

import SwiftUI
import CoreSpotlight
import AppKit

public struct RecentsListView: View {

    @Environment(\.colorScheme)
    private var colorScheme

    @Binding private var recentProjects: [URL]
    @Binding private var selection: Set<URL>
    @State private var rightClickedItems: Set<URL> = []

    @FocusState.Binding private var focusedField: FocusTarget?
    private let dismissWindow: () -> Void
    private let openHandler: WelcomeOpenHandler

    public init(
        recentProjects: Binding<[URL]>,
        selection: Binding<Set<URL>>,
        focusedField: FocusState<FocusTarget?>.Binding,
        dismissWindow: @escaping () -> Void,
        openHandler: @escaping WelcomeOpenHandler
    ) {
        self._recentProjects = recentProjects
        self._selection = selection
        self._focusedField = focusedField
        self.dismissWindow = dismissWindow
        self.openHandler = openHandler
    }

    private var isFocused: Bool {
        focusedField == .recentProjects
    }

    @ViewBuilder private var listEmptyView: some View {
        VStack {
            Spacer()
            Text("No Recent Projects")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    public var body: some View {
        List(recentProjects, id: \.self, selection: $selection) { project in
            RecentsListItem(projectPath: project)
        }
        .focused($focusedField, equals: .recentProjects)
        .contextMenu(forSelectionType: URL.self) { items in
            if !items.isEmpty {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(Array(items))
                }

                Button("Copy path\(items.count > 1 ? "s" : "")") {
                    let pasteBoard = NSPasteboard.general
                    pasteBoard.clearContents()
                    pasteBoard.writeObjects(items.map(\.relativePath) as [NSString])
                }

                Button("Remove from Recents") {
                    removeRecentProjects(urls: Set(items))
                }
            }
        } primaryAction: { items in
            openHandler(Array(items), dismissWindow)
        }
        .onCopyCommand {
            selection.map { NSItemProvider(object: $0.path(percentEncoded: false) as NSString) }
        }
        .onDeleteCommand {
            removeRecentProjects()
        }
        .background {
            Button("") {
                openHandler(Array(selection), dismissWindow)
            }
            .keyboardShortcut(.defaultAction)
            .hidden()
        }
        .overlay {
            if recentProjects.isEmpty {
                listEmptyView
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: RecentsStore.didUpdateNotification)) { _ in
            updateRecentProjects()
        }
    }

    // MARK: - Actions

    private func removeRecentProjects(urls: Set<URL>? = nil) {
        let targets = urls ?? selection
        recentProjects = RecentsStore.removeRecentProjects(targets)
    }

    private func updateRecentProjects() {
        recentProjects = RecentsStore.recentProjectURLs()
        if !recentProjects.isEmpty {
            selection = Set(recentProjects.prefix(1))
        }
    }
}
