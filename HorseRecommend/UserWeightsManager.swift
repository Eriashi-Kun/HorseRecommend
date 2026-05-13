import Foundation
import Observation

@MainActor
@Observable
class UserWeightsManager {
    var jockey: Double     = 50
    var history: Double    = 50
    var popularity: Double = 50
    var cuteness: Double   = 0
    var intuition: Double  = 0

    init() {
        let ud = UserDefaults.standard
        jockey     = ud.object(forKey: "w_jockey")     != nil ? ud.double(forKey: "w_jockey")     : 50
        history    = ud.object(forKey: "w_history")    != nil ? ud.double(forKey: "w_history")    : 50
        popularity = ud.object(forKey: "w_popularity") != nil ? ud.double(forKey: "w_popularity") : 50
        cuteness   = ud.object(forKey: "w_cuteness")   != nil ? ud.double(forKey: "w_cuteness")   : 0
        intuition  = ud.object(forKey: "w_intuition")  != nil ? ud.double(forKey: "w_intuition")  : 0
    }

    func save() {
        let ud = UserDefaults.standard
        ud.set(jockey,     forKey: "w_jockey")
        ud.set(history,    forKey: "w_history")
        ud.set(popularity, forKey: "w_popularity")
        ud.set(cuteness,   forKey: "w_cuteness")
        ud.set(intuition,  forKey: "w_intuition")
    }

    func reset() {
        jockey     = 50
        history    = 50
        popularity = 50
        cuteness   = 0
        intuition  = 0
    }

    var isCustomized: Bool {
        jockey != 50 || history != 50 || popularity != 50 || cuteness != 0 || intuition != 0
    }
}
