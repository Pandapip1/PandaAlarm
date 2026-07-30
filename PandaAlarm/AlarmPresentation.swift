//
//  AlarmPresentation.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/29/26.
//

import AlarmKit
import SwiftUI

func makePresentation(meta: AlarmInstanceMetadata) -> AlarmPresentation {
    return AlarmPresentation(
        alert: AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: meta.title)
        ),
        countdown: AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: meta.title)
        ),
        paused: AlarmPresentation.Paused(
            title: LocalizedStringResource(stringLiteral: "This shouldn't happen"),
            resumeButton: AlarmButton(
                text: "Resume",
                textColor: .secondary,
                systemImageName: "play.circle.fill"
            )
        )
    )
}
