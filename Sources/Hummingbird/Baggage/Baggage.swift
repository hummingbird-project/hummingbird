//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import InstrumentationBaggage

extension HBRequest {
    var baggage: Baggage {
        get { self.extensions.get(\.baggage) ?? Baggage.topLevel }
        set { self.extensions.set(\.baggage, value: newValue) }
    }

    func withBaggage<Return>(_ baggage: Baggage, process: (HBRequest) -> Return) -> Return {
        var request = self
        request.baggage = baggage
        return process(request)
    }
}