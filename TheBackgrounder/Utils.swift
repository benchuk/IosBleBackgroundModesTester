

import Foundation


class Utils
{
  static func evaluatePerformance(prefixText:String, actionBlock: () -> Void) -> Void
  {
    
    let start = DispatchTime.now() // <<<<<<<<<< Start time
    actionBlock()
    let end = DispatchTime.now()   // <<<<<<<<<<   end time
    
    let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
    let milisec = Double(nanoTime) / 1000000 // Technically could overflow for long running tests
    
    print("Time for action -> \(prefixText) took: \(milisec) milisec")
  }
}
