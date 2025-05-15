// ModalDismisser.swift
// Helper class to ensure modals are properly dismissed before navigation

import UIKit

class ModalDismisser {
    static func dismissAllModals(completion: @escaping () -> Void) {
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            completion()
            return
        }
        
        dismissModalRecursively(from: rootViewController) {
            // Add small delay to ensure animations complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
        }
    }
    
    private static func dismissModalRecursively(from viewController: UIViewController, completion: @escaping () -> Void) {
        if let presented = viewController.presentedViewController {
            presented.dismiss(animated: false) {
                dismissModalRecursively(from: viewController, completion: completion)
            }
        } else {
            completion()
        }
    }
}
