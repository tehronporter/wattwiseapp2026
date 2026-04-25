import Foundation

// MARK: - Quiz Node Status

enum QuizNodeStatus: Equatable, Hashable {
    case locked
    case available
    case completed(bestScore: Double)
    case masteryNeeded(bestScore: Double)

    var isPassed: Bool {
        if case .completed(let s) = self { return s >= 0.7 }
        return false
    }

    var isUnlocked: Bool {
        switch self {
        case .locked: return false
        default: return true
        }
    }

    var bestScore: Double? {
        switch self {
        case .completed(let s), .masteryNeeded(let s): return s
        default: return nil
        }
    }
}

// MARK: - Practice Node

struct PracticeNode: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let topicTags: [String]
    let questionCount: Int
    let estimatedMinutes: Int
    let isCheckpoint: Bool
    var status: QuizNodeStatus

    var quizType: QuizType {
        isCheckpoint ? .fullPracticeExam : .quickQuiz
    }
}

// MARK: - Practice Unit

struct PracticeUnit: Identifiable {
    let id: String
    let title: String
    let nodes: [PracticeNode]

    var passedCount: Int { nodes.filter { $0.status.isPassed }.count }
    var totalCount: Int { nodes.count }
    var progress: Double {
        guard !nodes.isEmpty else { return 0 }
        return Double(passedCount) / Double(nodes.count)
    }
}

// MARK: - Practice Path

struct PracticePath {
    let examType: ExamType
    let units: [PracticeUnit]

    var allNodes: [PracticeNode] { units.flatMap { $0.nodes } }
    var passedCount: Int { allNodes.filter { $0.status.isPassed }.count }
    var totalCount: Int { allNodes.count }

    var nextAvailableNode: PracticeNode? {
        allNodes.first { $0.status == .available }
    }

    var nextActionNode: PracticeNode? {
        // Prioritize mastery-needed nodes, then first available
        allNodes.first { if case .masteryNeeded = $0.status { return true }; return false }
            ?? allNodes.first { $0.status == .available }
    }
}

// MARK: - Static Path Definitions

extension PracticePath {
    static func forExamType(_ examType: ExamType) -> PracticePath {
        switch examType {
        case .apprentice: return apprenticePath
        case .journeyman:  return journeymanPath
        case .master:      return masterPath
        }
    }

    static var apprenticePath: PracticePath {
        PracticePath(examType: .apprentice, units: [
            PracticeUnit(id: "app-u1", title: "Getting Started", nodes: [
                PracticeNode(id: "app-1-1",
                             title: "Electrical Basics",
                             subtitle: "Voltage, current, resistance, and power fundamentals",
                             topicTags: ["Electrical Theory"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .available),
                PracticeNode(id: "app-1-2",
                             title: "Safety & Code",
                             subtitle: "Job site safety, PPE, and code compliance basics",
                             topicTags: ["Safety", "Trade Knowledge"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "app-1-3",
                             title: "Electrician Math",
                             subtitle: "Fractions, decimals, and basic electrical formulas",
                             topicTags: ["Electrician Math"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
            ]),
            PracticeUnit(id: "app-u2", title: "Core Theory", nodes: [
                PracticeNode(id: "app-2-1",
                             title: "Ohm's Law",
                             subtitle: "E=IR, power triangle, and circuit analysis",
                             topicTags: ["Electrical Theory"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "app-2-2",
                             title: "Wiring Methods",
                             subtitle: "Conductors, cable types, raceways, and installation",
                             topicTags: ["Wiring Methods and Installation"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "app-2-3",
                             title: "NEC Fundamentals",
                             subtitle: "Code structure, Article 90–100 definitions, and scope",
                             topicTags: ["NEC Fundamentals", "Trade Knowledge"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
            ]),
            PracticeUnit(id: "app-u3", title: "Unit Checkpoint", nodes: [
                PracticeNode(id: "app-3-1",
                             title: "Apprentice Exam Sim",
                             subtitle: "Timed 25-question practice exam · 45 min",
                             topicTags: ["Electrical Theory", "Safety", "Electrician Math",
                                         "Wiring Methods and Installation", "NEC Fundamentals", "Trade Knowledge"],
                             questionCount: 25, estimatedMinutes: 45,
                             isCheckpoint: true, status: .locked),
            ]),
        ])
    }

    static var journeymanPath: PracticePath {
        PracticePath(examType: .journeyman, units: [
            PracticeUnit(id: "jour-u1", title: "Theory & Grounding", nodes: [
                PracticeNode(id: "jour-1-1",
                             title: "Electrical Theory",
                             subtitle: "AC/DC theory, power factor, inductance, and transformers",
                             topicTags: ["Electrical Theory"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .available),
                PracticeNode(id: "jour-1-2",
                             title: "Grounding & Bonding",
                             subtitle: "Article 250, EGC, GEC, bonding jumpers, and GFPE",
                             topicTags: ["Grounding and Bonding"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "jour-1-3",
                             title: "Branch Circuits",
                             subtitle: "Article 210, circuit ratings, AFCI, GFCI, and multi-wire circuits",
                             topicTags: ["Branch Circuits", "Wiring Methods and Installation"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
            ]),
            PracticeUnit(id: "jour-u2", title: "Installation & Systems", nodes: [
                PracticeNode(id: "jour-2-1",
                             title: "Feeders & Services",
                             subtitle: "Articles 225–230, service entrance, metering, and sizing",
                             topicTags: ["Wiring Methods and Installation", "Trade Knowledge"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "jour-2-2",
                             title: "Raceway & Box Fill",
                             subtitle: "Conduit fill calculations, box fill, and device box sizing",
                             topicTags: ["Wiring Methods and Installation", "Electrician Math"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "jour-2-3",
                             title: "Motors",
                             subtitle: "Article 430, motor calculations, overload protection, and sizing",
                             topicTags: ["Motors"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
            ]),
            PracticeUnit(id: "jour-u3", title: "Calculations & Protection", nodes: [
                PracticeNode(id: "jour-3-1",
                             title: "Load Calculations",
                             subtitle: "Residential and small commercial demand factor methods",
                             topicTags: ["Load Calculations", "Electrician Math"],
                             questionCount: 10, estimatedMinutes: 15,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "jour-3-2",
                             title: "Overcurrent Protection",
                             subtitle: "Fuses, breakers, Article 240, ratings, and interrupting capacity",
                             topicTags: ["Overcurrent Protection"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
            ]),
            PracticeUnit(id: "jour-u4", title: "Unit Checkpoint", nodes: [
                PracticeNode(id: "jour-4-1",
                             title: "Journeyman Exam Sim",
                             subtitle: "Timed 25-question practice exam · 45 min",
                             topicTags: ["Electrical Theory", "Grounding and Bonding", "Branch Circuits",
                                         "Load Calculations", "Overcurrent Protection", "Motors",
                                         "Wiring Methods and Installation"],
                             questionCount: 25, estimatedMinutes: 45,
                             isCheckpoint: true, status: .locked),
            ]),
        ])
    }

    static var masterPath: PracticePath {
        PracticePath(examType: .master, units: [
            PracticeUnit(id: "mas-u1", title: "Advanced Code & Calculations", nodes: [
                PracticeNode(id: "mas-1-1",
                             title: "Advanced NEC",
                             subtitle: "Complex code lookups, cross-article application, Article 100 definitions",
                             topicTags: ["Advanced NEC", "Trade Knowledge", "NEC Fundamentals"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .available),
                PracticeNode(id: "mas-1-2",
                             title: "Service Calculations",
                             subtitle: "Optional and standard calculation methods for large services",
                             topicTags: ["Load Calculations", "Electrician Math"],
                             questionCount: 10, estimatedMinutes: 15,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "mas-1-3",
                             title: "Special Occupancies",
                             subtitle: "Articles 500–517, hazardous locations and classified areas",
                             topicTags: ["Special Occupancies", "Trade Knowledge"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
            ]),
            PracticeUnit(id: "mas-u2", title: "Systems & Protection", nodes: [
                PracticeNode(id: "mas-2-1",
                             title: "Motors & Generators",
                             subtitle: "Articles 430–445, motor sizing, overload protection, and generators",
                             topicTags: ["Motors"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "mas-2-2",
                             title: "Fault Protection",
                             subtitle: "Short circuit, ground fault, coordination, and AIC ratings",
                             topicTags: ["Overcurrent Protection", "Grounding and Bonding"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "mas-2-3",
                             title: "Plan Reading",
                             subtitle: "Electrical drawings, riser diagrams, symbols, and specs",
                             topicTags: ["Trade Knowledge"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
                PracticeNode(id: "mas-2-4",
                             title: "Code Application",
                             subtitle: "Mixed code scenarios and applied NEC problem solving",
                             topicTags: ["Advanced NEC", "NEC Fundamentals", "Trade Knowledge"],
                             questionCount: 10, estimatedMinutes: 10,
                             isCheckpoint: false, status: .locked),
            ]),
            PracticeUnit(id: "mas-u3", title: "Unit Checkpoint", nodes: [
                PracticeNode(id: "mas-3-1",
                             title: "Master Exam Simulation",
                             subtitle: "Timed 25-question master-level practice exam · 45 min",
                             topicTags: ["Advanced NEC", "Load Calculations", "Special Occupancies",
                                         "Overcurrent Protection", "Motors", "Grounding and Bonding"],
                             questionCount: 25, estimatedMinutes: 45,
                             isCheckpoint: true, status: .locked),
            ]),
        ])
    }
}
