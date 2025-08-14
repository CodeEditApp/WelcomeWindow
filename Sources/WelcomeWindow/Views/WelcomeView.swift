//
//  WelcomeView.swift
//  CodeEditModules/WelcomeModule
//
//  Created by Ziyuan Zhao on 2022/3/18.
//

import SwiftUI
import AppKit
import Foundation

public struct WelcomeView<SubtitleView: View>: View {

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.controlActiveState)
    private var controlActiveState

    @State private var isHoveringCloseButton = false
    @State private var appIconAverageColor: Color = .accentColor

    @FocusState.Binding var focusedField: FocusTarget?

    private let dismissWindow: () -> Void
    private let actions: WelcomeActions
    private let subtitleView: (() -> SubtitleView)?

    let iconImage: Image?
    let title: String?

    var isMacOS26: Bool {
        if #available(macOS 26, *) {
            return true
        } else {
            return false
        }
    }

    public init(
        iconImage: Image? = nil,
        title: String? = nil,
        subtitleView: (() -> SubtitleView)? = nil,
        actions: WelcomeActions,
        dismissWindow: @escaping () -> Void,
        focusedField: FocusState<FocusTarget?>.Binding
    ) {
        self.iconImage = iconImage
        self.title = title
        self.subtitleView = subtitleView
        self.actions = actions
        self.dismissWindow = dismissWindow
        self._focusedField = focusedField
    }

    private var appVersion: String { Bundle.versionString ?? "" }
    private var appBuild: String { Bundle.buildString ?? "" }
    private var appVersionPostfix: String { Bundle.versionPostfix ?? "" }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            mainContent
            dismissButton
        }
    }

    @ViewBuilder private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)
            ZStack {
                if colorScheme == .dark {
                    Rectangle()
                        .frame(width: 104, height: 104)
                        .foregroundColor(appIconAverageColor)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .blur(radius: 64)
                        .opacity(0.5)
                }
                (iconImage ?? Image(nsImage: NSApp.applicationIconImage))
                    .resizable()
                    .frame(width: 128, height: 128)
            }

            Text(title ?? Bundle.displayName)
                .font(.system(size: 36, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if let subtitleView {
                    subtitleView()
                } else {
                    Text(String(
                        format: "Version %@%@ (%@)",
                        appVersion, appVersionPostfix, appBuild
                    ))
                }
            }
            .foregroundColor(.secondary)
            .font(.system(size: 13.5))

            Spacer().frame(height: 40)

            HStack {
                VStack(alignment: .leading, spacing: isMacOS26 ? 6 : 8) {
                    switch actions {
                    case .none:
                        EmptyView()
                    case .one(let view1):
                        Spacer()
                        view1
                            .focused($focusedField, equals: .action1)
                        Spacer()
                    case let .two(view1, view2):
                        Spacer()
                        view1
                            .focused($focusedField, equals: .action1)
                        view2
                            .focused($focusedField, equals: .action2)
                        Spacer()
                    case let .three(view1, view2, view3):
                        view1
                            .focused($focusedField, equals: .action1)
                        view2
                            .focused($focusedField, equals: .action2)
                        view3
                            .focused($focusedField, equals: .action3)
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal, 56)
        .padding(.bottom, 16)
        .frame(width: 460)
        .frame(maxHeight: .infinity)
        .background {
            if colorScheme == .dark {
                Color(.black).opacity(0.275)
                    .background(.ultraThickMaterial)
            } else {
                Color(.white)
                    .background(.regularMaterial)
            }
        }
        .onAppear {
            if let averageNSColor = NSApp.applicationIconImage.dominantColor() {
                appIconAverageColor = Color(averageNSColor)
            }
        }
    }

    @ViewBuilder private var dismissButton: some View {
        Button(action: dismissWindow) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(isHoveringCloseButton ? Color(.secondaryLabelColor) : Color(.tertiaryLabelColor))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close"))
        .focused($focusedField, equals: .dismissButton)
        .modifier(FocusRingModifier(isFocused: focusedField == .dismissButton, shape: .circle))
        .onHover { hover in
            withAnimation(.linear(duration: 0.15)) {
                isHoveringCloseButton = hover
            }
        }
        .padding(10)
        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
    }
}
