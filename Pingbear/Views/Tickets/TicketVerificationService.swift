import Vision

class TicketVerificationService {
    static let shared = TicketVerificationService()
    private init() {}
    
    // UPDATED: Added matchedEvent property to store the found event
    struct TicketVerificationResult {
        let isValid: Bool
        let matchedEvent: Event?  // NEW: Store matched event
        let barcode: String?
        let date: Date?
        let location: String?
        let error: String?
    }
    
    // MARK: - Screenshot Detection
    private func isScreenshot(_ image: CGImage) -> Bool {
        let aspectRatio = Double(image.width) / Double(image.height)
        
        // More flexible aspect ratio checks
        let isPhoneRatio = aspectRatio < 1.0  // Most phone screenshots are taller than wide
        let hasHighQuality = image.bitsPerPixel >= 24
        
        return isPhoneRatio && hasHighQuality
    }
    
    // MARK: - Date Matching Helper
    private func matchesEventDate(_ text: String, event: Event) -> Bool {
        let calendar = Calendar.current
        let eventComponents = calendar.dateComponents([.day, .month, .year], from: event.startDateTime)
        
        guard let eventDay = eventComponents.day,
              let eventMonth = eventComponents.month,
              let eventYear = eventComponents.year else {
            return false
        }
        
        // Prepare different month formats
        let shortMonth = DateFormatter().shortMonthSymbols[eventMonth - 1]  // "Oct"
        let longMonth = DateFormatter().monthSymbols[eventMonth - 1]     // "October"
        let numericMonth = String(format: "%02d", eventMonth)           // "10"
        
        // Prepare different year formats
        let shortYear = String(eventYear % 100)  // "24"
        let fullYear = String(eventYear)         // "2024"
        
        // Prepare different day formats
        let dayFormats = [
            String(eventDay),                    // "31"
            String(format: "%02d", eventDay),    // "01" for single digit days
            "\(eventDay)st", "\(eventDay)nd", "\(eventDay)rd", "\(eventDay)th"  // Ordinal formats
        ]
        
        // Convert text to lowercase for easier matching
        let lowercaseText = text.lowercased()
        
        // Check if any combination of day/month/year exists in the text
        let hasMonth = lowercaseText.contains(shortMonth.lowercased()) ||
                      lowercaseText.contains(longMonth.lowercased()) ||
                      lowercaseText.contains(numericMonth)
        
        let hasYear = lowercaseText.contains(shortYear) ||
                     lowercaseText.contains(fullYear)
        
        let hasDay = dayFormats.contains { format in
            lowercaseText.contains(format.lowercased())
        }
        
        return hasDay && hasMonth && hasYear
    }
    
    // MARK: - Location Matching Helper
    private func matchesEventLocation(_ text: String, location: String) -> Bool {
        let textWords = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let locationWords = location.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        // Check if any location word variation exists in the text
        for locationWord in locationWords where locationWord.count > 2 {  // Ignore small words
            let hasMatch = textWords.contains { textWord in
                textWord.contains(locationWord) || locationWord.contains(textWord)
            }
            if !hasMatch {
                return false
            }
        }
        return true
    }
    
    // NEW: Added method to verify ticket without requiring an event
    func verifyTicketAndFindEvent(image: CGImage) async -> TicketVerificationResult {
        // Verify screenshot
        guard isScreenshot(image) else {
            return TicketVerificationResult(
                isValid: false,
                matchedEvent: nil,
                barcode: nil,
                date: nil,
                location: nil,
                error: "Please upload a clear image of your full ticket"
            )
        }
        
        // Setup Vision requests
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        
        let barcodeRequest = VNDetectBarcodesRequest()
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        do {
            try requestHandler.perform([textRequest, barcodeRequest])
            
            guard let textObservations = textRequest.results else {
                return TicketVerificationResult(
                    isValid: false,
                    matchedEvent: nil,
                    barcode: nil,
                    date: nil,
                    location: nil,
                    error: "Could not read ticket text clearly"
                )
            }
            
            let recognizedText = textObservations.compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence > 0.5 else { return nil }
                return candidate.string
            }.joined(separator: " ")
            
            // For debugging
            print("Recognized text:", recognizedText)
            
            let barcode = (barcodeRequest.results)?.first?.payloadStringValue
            
            // NEW: Fetch all events and find a match
            let eventsModel = EventsModel()
            await eventsModel.fetchPublicEvents()
            
            print("DEBUG: Found \(eventsModel.events.count) events")

            // When checking for matches:
            for event in eventsModel.events {
                print("DEBUG: Checking event: \(event.description)")
                print("DEBUG: Date match: \(matchesEventDate(recognizedText, event: event))")
                print("DEBUG: Location match: \(matchesEventLocation(recognizedText, location: event.location))")
            }
            
            for event in eventsModel.events {
                print("DEBUG: Event: \(event.description) at \(event.location) on \(event.startDateTime)")
            }
            
            // NEW: Look for matching event based on date and location
            if let matchedEvent = eventsModel.events.first(where: { event in
                matchesEventDate(recognizedText, event: event) &&
                matchesEventLocation(recognizedText, location: event.location)
            }) {
                return TicketVerificationResult(
                    isValid: true,
                    matchedEvent: matchedEvent,
                    barcode: barcode,
                    date: matchedEvent.startDateTime,
                    location: matchedEvent.location,
                    error: nil
                )
            }
            
            return TicketVerificationResult(
                isValid: false,
                matchedEvent: nil,
                barcode: barcode,
                date: nil,
                location: nil,
                error: "No matching competition found for this ticket"
            )
            
        } catch {
            return TicketVerificationResult(
                isValid: false,
                matchedEvent: nil,
                barcode: nil,
                date: nil,
                location: nil,
                error: "Error processing ticket: \(error.localizedDescription)"
            )
        }
    }
    
    // UPDATED: Modified to include matchedEvent in result
    func verifyTicket(image: CGImage, event: Event) async -> TicketVerificationResult {
        // Verify screenshot
        guard isScreenshot(image) else {
            return TicketVerificationResult(
                isValid: false,
                matchedEvent: nil,  // UPDATED: Added nil event
                barcode: nil,
                date: nil,
                location: nil,
                error: "Please upload a clear image of your full ticket"
            )
        }
        
        // Setup Vision requests
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        
        let barcodeRequest = VNDetectBarcodesRequest()
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        do {
            try requestHandler.perform([textRequest, barcodeRequest])
            
            // Extract text
            guard let textObservations = textRequest.results else {
                return TicketVerificationResult(
                    isValid: false,
                    matchedEvent: nil,  // UPDATED: Added nil event
                    barcode: nil,
                    date: nil,
                    location: nil,
                    error: "Could not read ticket text clearly"
                )
            }
            
            let recognizedText = textObservations.compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence > 0.5 else { return nil }
                return candidate.string
            }.joined(separator: " ")
            
            // For debugging
            print("Recognized text:", recognizedText)
            
            // Check for barcode
            let barcode = (barcodeRequest.results)?.first?.payloadStringValue
            
            // Verify components
            let hasValidDate = matchesEventDate(recognizedText, event: event)
            let hasValidLocation = matchesEventLocation(recognizedText, location: event.location)
            let hasBarcode = barcode != nil
            
            // Build error message if needed
            var errorParts: [String] = []
            if !hasValidDate { errorParts.append("event date") }
            if !hasValidLocation { errorParts.append("event location") }
            if !hasBarcode { errorParts.append("ticket barcode") }
            
            let isValid = hasValidDate && hasValidLocation && hasBarcode
            
            return TicketVerificationResult(
                isValid: isValid,
                matchedEvent: isValid ? event : nil,  // UPDATED: Include event if valid
                barcode: barcode,
                date: isValid ? event.startDateTime : nil,
                location: isValid ? event.location : nil,
                error: isValid ? nil : "Could not verify \(errorParts.joined(separator: " or "))"
            )
            
        } catch {
            return TicketVerificationResult(
                isValid: false,
                matchedEvent: nil,  // UPDATED: Added nil event
                barcode: nil,
                date: nil,
                location: nil,
                error: "Error processing ticket: \(error.localizedDescription)"
            )
        }
    }
}
