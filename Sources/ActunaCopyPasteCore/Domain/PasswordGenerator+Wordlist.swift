import Foundation

extension PasswordGenerator {
    /// Built-in passphrase wordlist.
    ///
    /// NOTE: this curated starter list (~256 distinct words, ~8 bits/word) keeps
    /// the package self-contained. For production-grade passphrases, inject the
    /// full EFF large wordlist (7776 words, ~12.9 bits/word) as a bundled
    /// resource via `PasswordGenerator(randomness:wordlist:)`.
    public static let defaultWordlist: [String] = [
        "able", "acid", "acorn", "actor", "agile", "alarm", "album", "alert",
        "alley", "amber", "amend", "angle", "ankle", "apple", "april", "arbor",
        "arena", "armor", "arrow", "aside", "asset", "atlas", "audio", "azure",
        "bacon", "badge", "baker", "banjo", "barge", "basil", "basin", "batch",
        "beach", "beard", "beast", "bench", "berry", "birch", "blaze", "blend",
        "blink", "bloom", "blush", "board", "bonus", "boost", "booth", "brave",
        "bread", "brick", "brief", "broom", "brush", "buddy", "build", "bunch",
        "cabin", "cable", "cacao", "camel", "candy", "canoe", "canon", "cargo",
        "carol", "cedar", "chalk", "charm", "chase", "cheer", "chess", "chief",
        "chime", "civic", "claim", "clamp", "clean", "clerk", "cliff", "cloak",
        "clock", "cloud", "clove", "clump", "coach", "coast", "cobra", "comet",
        "coral", "couch", "cover", "crane", "crate", "creek", "crisp", "crown",
        "crumb", "curve", "daisy", "dance", "dealer", "delta", "denim", "depot",
        "diary", "diner", "ditch", "dodge", "donor", "dough", "draft", "drama",
        "dream", "dress", "drift", "drink", "drive", "eagle", "early", "earth",
        "easel", "ebony", "elbow", "elder", "ember", "emery", "enjoy", "envoy",
        "equal", "essay", "ethos", "fable", "facet", "fairy", "fancy", "favor",
        "feast", "fence", "ferry", "fiber", "field", "final", "fjord", "flame",
        "flask", "fleet", "flint", "float", "flock", "flora", "flour", "flute",
        "focus", "forge", "fox", "frost", "fruit", "fudge", "gauge", "ghost",
        "giant", "glade", "glass", "globe", "glory", "glove", "grace", "grain",
        "grape", "grass", "grove", "guava", "guide", "habit", "happy", "haven",
        "hazel", "heart", "hedge", "honey", "hotel", "house", "human", "humor",
        "ideal", "igloo", "image", "index", "ivory", "jelly", "jewel", "joker",
        "jolly", "joust", "judge", "juice", "karma", "kayak", "ketchup", "kite",
        "knack", "koala", "label", "lager", "lance", "larch", "lemon", "level",
        "lever", "light", "lilac", "linen", "liver", "llama", "lobby", "lodge",
        "lotus", "lucky", "lunar", "lyric", "magic", "mango", "maple", "march",
        "marsh", "medal", "melon", "mercy", "metal", "mango", "miner", "mocha",
        "money", "month", "moose", "motor", "mound", "mural", "music", "nacho",
        "navy", "nerve", "niece", "noble", "north", "novel", "nurse", "oasis",
        "ocean", "olive", "onion", "opera", "orbit", "otter", "ozone", "paddle",
        "panda", "paper", "patio", "peach", "pearl", "pedal", "penny", "perch",
        "piano", "pilot", "pixel", "plaza", "poet", "porch", "power", "prism",
        "prize", "proud", "pulse", "quail", "quartz", "quest", "quill", "quilt",
        "radar", "raven", "realm", "reign", "relay", "ridge", "rifle", "river",
        "robin", "rocket", "rose", "royal", "ruby", "rural", "saddle", "salsa",
        "sauce", "scarf", "scout", "sedan", "shade", "shark", "sheep", "shelf",
        "shine", "shore", "siren", "skate", "skiff", "slate", "sloth", "smile",
        "smoke", "snail", "solar", "sonic", "spade", "spark", "spice", "spine",
        "spoon", "sport", "spray", "spruce", "squad", "stage", "stalk", "steam",
        "steel", "stone", "stork", "storm", "stove", "straw", "swarm", "sweet",
        "swift", "table", "tango", "taper", "teach", "thorn", "tiger", "tonic",
        "topaz", "torch", "tower", "trace", "track", "trail", "trend", "tribe",
        "trout", "tulip", "tutor", "ultra", "umbra", "uncle", "union", "unity",
        "urban", "usher", "valve", "vapor", "vault", "venom", "verge", "vigor",
        "viola", "vivid", "vocal", "vowel", "wafer", "wagon", "waltz", "water",
        "wheat", "whale", "wharf", "wheel", "whisk", "willow", "wiper", "witty",
        "woven", "yacht", "yeast", "yodel", "youth", "zebra", "zesty", "zonal"
    ]
}
