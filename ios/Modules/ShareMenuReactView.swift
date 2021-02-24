//
//  ShareMenuReactView.swift
//  RNShareMenu
//
//  Created by Gustavo Parreira on 28/07/2020.
//

import MobileCoreServices

@objc(ShareMenuReactView)
public class ShareMenuReactView: NSObject {
    static var viewDelegate: ReactShareViewDelegate?

    @objc
    static public func requiresMainQueueSetup() -> Bool {
        return false
    }

    public static func attachViewDelegate(_ delegate: ReactShareViewDelegate!) {
        guard (ShareMenuReactView.viewDelegate == nil) else { return }

        ShareMenuReactView.viewDelegate = delegate
    }

    public static func detachViewDelegate() {
        ShareMenuReactView.viewDelegate = nil
    }

    @objc(dismissExtension:)
    func dismissExtension(_ error: String?) {
        guard let extensionContext = ShareMenuReactView.viewDelegate?.loadExtensionContext() else {
            print("Error: \(NO_EXTENSION_CONTEXT_ERROR)")
            return
        }

        if error != nil {
            let exception = NSError(
                domain: Bundle.main.bundleIdentifier!,
                code: DISMISS_SHARE_EXTENSION_WITH_ERROR_CODE,
                userInfo: ["error": error!]
            )
            extensionContext.cancelRequest(withError: exception)
            return
        }

        extensionContext.completeRequest(returningItems: [], completionHandler: nil)
    }

    @objc
    func openApp() {
        guard let viewDelegate = ShareMenuReactView.viewDelegate else {
            print("Error: \(NO_DELEGATE_ERROR)")
            return
        }

        viewDelegate.openApp()
    }

    @objc(continueInApp:)
    func continueInApp(_ extraData: [String:Any]?) {
        guard let viewDelegate = ShareMenuReactView.viewDelegate else {
            print("Error: \(NO_DELEGATE_ERROR)")
            return
        }

        let extensionContext = viewDelegate.loadExtensionContext()

        guard let item = extensionContext.inputItems.first as? NSExtensionItem else {
            print("Error: \(COULD_NOT_FIND_ITEM_ERROR)")
            return
        }

        viewDelegate.continueInApp(with: item, and: extraData)
    }

    @objc(data:reject:)
    func data(_
            resolve: @escaping RCTPromiseResolveBlock,
            reject: @escaping RCTPromiseRejectBlock) {
        guard let extensionContext = ShareMenuReactView.viewDelegate?.loadExtensionContext() else {
            print("Error: \(NO_EXTENSION_CONTEXT_ERROR)")
            return
        }

        extractDataFromContext(context: extensionContext) { (data, mimeType, error) in
            guard (error == nil) else {
                reject("error", error?.description, nil)
                return
            }

            resolve([MIME_TYPE_KEY: mimeType, DATA_KEY: data])
        }
    }

    func extractDataFromContext(context: NSExtensionContext, withCallback callback: @escaping (String?, String?, NSException?) -> Void) {
        let item:NSExtensionItem! = context.inputItems.first as? NSExtensionItem
        let attachments:[AnyObject]! = item.attachments
        var urlProvider = [NSItemProvider]()
        var imageProvider = [NSItemProvider]()
        var textProvider:NSItemProvider! = nil
        var dataProvider:NSItemProvider! = nil
        
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                urlProvider.append(provider as? NSItemProvider ?? NSItemProvider())
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                textProvider = provider as? NSItemProvider
                break
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                imageProvider.append(provider as? NSItemProvider ?? NSItemProvider())
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypeData as String) {
                dataProvider = provider as? NSItemProvider
                break
            }
        }
        if (urlProvider.count > 0) {
            var totalUrl = ""
            var i = 0
            for urlItem in urlProvider {
                urlItem.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (item, error) in
                    let url: URL! = item as? NSURL as URL?
                    i += 1;
                    let isLastIndex = i == urlProvider.count
                    totalUrl = totalUrl + url!.absoluteString + (isLastIndex ? "" : ";")
                    if(isLastIndex){
                        callback("\(totalUrl)", "text/plain", nil)
                    }
                }
            }
        } else if (imageProvider.count > 0) {
            var totalUrl = ""
            var i = 0;
            for imageItem in imageProvider {
                imageItem.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (item, error) in
                    let url = item as? URL
                    i += 1;
                    let isLastIndex = i == imageProvider.count
                    if(url != nil){
                        totalUrl = totalUrl + url!.absoluteString + (isLastIndex ? "" : ";")
                    }else{
                        let image: UIImage! = item as? UIImage
                        let imageName = UUID().uuidString
                        let urlString = self.saveImageDocumentDirectory(image: image, imageName: imageName, qually: 0.5)
                        totalUrl = totalUrl + urlString + (isLastIndex ? "" : ";")
                    }
                    
                    if(isLastIndex){
                        callback("\(totalUrl)" , "image/JPEG", nil)
                    }
                }
            }
        } else if (textProvider != nil) {
            textProvider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (item, error) in
                let text:String! = item as? String
                
                callback(text, "text/plain", nil)
            }
        }  else if (dataProvider != nil) {
            dataProvider.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil) { (item, error) in
                let url: URL! = item as? URL
                
                callback(url.absoluteString, self.extractMimeType(from: url), nil)
            }
        } else {
            callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"couldn't find provider", userInfo:nil))
        }
    }
    
    func saveImageDocumentDirectory(image: UIImage, imageName: String, qually: CGFloat)-> String{
      let fileManager = FileManager.default
      let paths = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString).appendingPathComponent(imageName)
      let imageData = image.jpegData(compressionQuality: qually)
      fileManager.createFile(atPath: paths as String, contents: imageData, attributes: nil)
      return "\(paths)"
    }

    func extractMimeType(from url: URL) -> String {
      let fileExtension: CFString = url.pathExtension as CFString
      guard let extUTI = UTTypeCreatePreferredIdentifierForTag(
              kUTTagClassFilenameExtension,
              fileExtension,
              nil
      )?.takeUnretainedValue() else { return "" }

      guard let mimeUTI = UTTypeCopyPreferredTagWithClass(extUTI, kUTTagClassMIMEType)
      else { return "" }

      return mimeUTI.takeUnretainedValue() as String
    }
}
