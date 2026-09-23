import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import Observation
import os
import UserMessagingPlatform

/// Consent, in a fixed order: the UMP consent form, then Apple's tracking prompt, then the
/// ads SDK, and only if consent allows ad requests at all.
///
/// The tracking prompt comes second so it lands after the form has explained what it is for.
/// Nothing may request an ad until all three steps are done.
@MainActor
@Observable
final class AdsConsent {
    /// Consent is settled and the SDK is up. Until then no strip is drawn and no ad asked for.
    private(set) var isReady = false

    /// This player's region requires a way back to their consent choices, which the
    /// settings sheet then has to offer.
    private(set) var offersPrivacyChoices = false

    func gather() async {
        #if DEBUG
        if DebugLaunch.resetsConsent { ConsentInformation.shared.reset() }
        #endif

        await updateConsentInfo()
        await presentFormIfRequired()
        offersPrivacyChoices = ConsentInformation.shared.privacyOptionsRequirementStatus == .required

        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        guard ConsentInformation.shared.canRequestAds else {
            Log.ads.error("Consent does not allow ad requests; nothing will be asked for")
            return
        }
        await startAdsSDK()
        Log.ads.info("Consent settled and the ads SDK is up")
        isReady = true
    }

    private func updateConsentInfo() async {
        await withCheckedContinuation { resume in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    Log.ads.error("Consent info did not update: \(String(describing: error), privacy: .public)")
                }
                resume.resume()
            }
        }
    }

    /// A no-op outside the regions that require a form. A failure is not fatal: what decides
    /// is `canRequestAds`, which stays false when consent was never given.
    private func presentFormIfRequired() async {
        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            Log.ads.error("Consent form did not present: \(String(describing: error), privacy: .public)")
        }
    }

    private func startAdsSDK() async {
        await withCheckedContinuation { resume in
            MobileAds.shared.start { status in
                for (name, adapter) in status.adapterStatusesByClassName where adapter.state != .ready {
                    Log.ads.error("Adapter \(name, privacy: .public) is not ready: \(adapter.description, privacy: .public)")
                }
                resume.resume()
            }
        }
    }

    /// Reopens the consent form, for regions that require a way back to it.
    func presentPrivacyChoices() async {
        try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
        offersPrivacyChoices = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private var parameters: RequestParameters {
        let parameters = RequestParameters()
        #if DEBUG
        if let region = DebugLaunch.consentRegion {
            let debug = DebugSettings()
            debug.geography = region == .europe ? .EEA : .other
            // A simulator already counts as a test device. On a real phone, paste in the
            // hashed id the console prints on the first run.
            debug.testDeviceIdentifiers = []
            parameters.debugSettings = debug
        }
        #endif
        return parameters
    }
}
