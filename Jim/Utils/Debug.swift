import AppKit

func measure(_ label: String, callback: (() -> ())) {
    let t0 = DispatchTime.now()
    callback()
    let t1 = DispatchTime.now()
    let dt = CGFloat(t1.uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000
    print("Took \(dt) ms to do \(label)")
}

func printResponderChain(from responder: NSResponder?) {
    var responder = responder
    while let r = responder {
        print(r)
        responder = r.nextResponder
    }
}
