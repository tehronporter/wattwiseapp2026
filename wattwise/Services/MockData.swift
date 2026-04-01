import Foundation

// MARK: - Mock Data for development / offline use

enum MockData {

    // MARK: - Modules & Lessons

    static let modules: [WWModule] = [
        WWModule(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            title: "Electrical Fundamentals",
            description: "Voltage, current, resistance, Ohm's Law, and basic circuit theory every electrician must master.",
            lessonCount: 5,
            estimatedMinutes: 45,
            topicTags: ["fundamentals", "ohms-law", "circuits"],
            progress: 0.6,
            lessons: fundamentalsLessons
        ),
        WWModule(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000002")!,
            title: "NEC Article 210 — Branch Circuits",
            description: "Branch circuit requirements, ratings, and GFCI/AFCI protection rules from NEC Article 210.",
            lessonCount: 4,
            estimatedMinutes: 40,
            topicTags: ["nec", "branch-circuits", "gfci", "afci"],
            progress: 0.25,
            lessons: article210Lessons
        ),
        WWModule(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000003")!,
            title: "Grounding & Bonding",
            description: "NEC Articles 250 and 680 — grounding electrode systems, bonding conductors, and equipment bonding.",
            lessonCount: 5,
            estimatedMinutes: 50,
            topicTags: ["grounding", "bonding", "nec-250"],
            progress: 0.0,
            lessons: groundingLessons
        ),
        WWModule(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000004")!,
            title: "Wiring Methods & Materials",
            description: "Cable types, conduit, wire sizing, ampacity tables, and permitted wiring methods under NEC Chapter 3.",
            lessonCount: 6,
            estimatedMinutes: 60,
            topicTags: ["wiring-methods", "conduit", "ampacity", "nec-chapter-3"],
            progress: 0.0,
            lessons: wiringLessons
        )
    ]

    // MARK: - Lessons

    static let fundamentalsLessons: [WWLesson] = [
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000001")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            title: "Voltage, Current & Resistance",
            topic: "Ohm's Law",
            estimatedMinutes: 10,
            status: .completed,
            completionPercentage: 1.0,
            sections: [
                LessonSection(id: UUID(), heading: "What is Voltage?", body: "Voltage (V) is the electrical pressure that pushes current through a circuit. Think of it like water pressure in a pipe — the higher the voltage, the more force pushing electrons along the conductor.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Current (Amperage)", body: "Current (I) is the rate of electron flow, measured in amperes (amps). A 15-amp circuit allows 15 coulombs of charge per second through the conductor.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Resistance", body: "Resistance (R) is the opposition to current flow, measured in ohms (Ω). Every conductor has some resistance — even copper wire.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Ohm's Law", body: "V = I × R\n\nIf voltage is 120V and resistance is 10Ω, current = 120 ÷ 10 = 12A.\n\nThis is the single most important formula in electrical work.", type: .callout)
            ],
            necReferences: []
        ),
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000002")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            title: "Power & Energy",
            topic: "Watts and Watt-Hours",
            estimatedMinutes: 8,
            status: .completed,
            completionPercentage: 1.0,
            sections: [
                LessonSection(id: UUID(), heading: "Power Formula", body: "Power (P) = Voltage × Current (P = V × I). A 120V circuit drawing 10A consumes 1,200 watts (1.2 kW).", type: .paragraph),
                LessonSection(id: UUID(), heading: "Energy vs Power", body: "Power is the rate of energy use. Energy = Power × Time. Running 1,200W for one hour = 1.2 kWh.", type: .paragraph)
            ],
            necReferences: []
        ),
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000003")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            title: "Series vs. Parallel Circuits",
            topic: "Circuit Theory",
            estimatedMinutes: 12,
            status: .inProgress,
            completionPercentage: 0.5,
            sections: [
                LessonSection(id: UUID(), heading: "Series Circuits", body: "In a series circuit, current flows through one path. Total resistance = R1 + R2 + R3. If one device fails, the circuit opens and everything stops.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Parallel Circuits", body: "In a parallel circuit, current has multiple paths. Total resistance decreases as more paths are added. Residential wiring is wired in parallel so each device operates independently.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Why Parallel Matters for Electricians", body: "Branch circuits in homes are parallel circuits. This is why adding more devices to a circuit increases total current draw — each device adds another parallel path.", type: .callout)
            ],
            necReferences: []
        ),
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000004")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            title: "AC vs. DC Power",
            topic: "Alternating & Direct Current",
            estimatedMinutes: 10,
            status: .notStarted,
            completionPercentage: 0.0,
            sections: [
                LessonSection(id: UUID(), heading: "Direct Current (DC)", body: "DC flows in one direction. Batteries produce DC. Used in electronics, solar systems, and EV charging.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Alternating Current (AC)", body: "AC reverses direction 60 times per second (60 Hz in the US). This is what comes out of your wall outlets. AC is used for distribution because voltage can be stepped up/down with transformers.", type: .paragraph)
            ],
            necReferences: []
        ),
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000005")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            title: "Conductors & Insulators",
            topic: "Materials",
            estimatedMinutes: 8,
            status: .notStarted,
            completionPercentage: 0.0,
            sections: [
                LessonSection(id: UUID(), heading: "Conductors", body: "Materials with low resistance that allow current to flow easily. Copper and aluminum are the most common in electrical wiring.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Insulators", body: "Materials with high resistance that block current flow. PVC, rubber, and nylon are common insulator materials used to coat conductors.", type: .paragraph)
            ],
            necReferences: []
        )
    ]

    static let article210Lessons: [WWLesson] = [
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000010")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000002")!,
            title: "Branch Circuit Ratings",
            topic: "NEC 210.3",
            estimatedMinutes: 10,
            status: .completed,
            completionPercentage: 1.0,
            sections: [
                LessonSection(id: UUID(), heading: "What is a Branch Circuit?", body: "A branch circuit is the circuit conductors between the final overcurrent device and the outlets it serves.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Standard Ratings", body: "15A, 20A, 30A, 40A, and 50A are the standard branch circuit ratings under NEC 210.3.", type: .callout, necCode: "210.3")
            ],
            necReferences: [
                NECReference(id: UUID(), code: "210.3", title: "Branch Circuit Ratings", summary: "Branch circuits shall be rated in accordance with the maximum permitted ampere rating of the overcurrent device.", expanded: nil)
            ]
        ),
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000011")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000002")!,
            title: "GFCI Protection Requirements",
            topic: "NEC 210.8",
            estimatedMinutes: 12,
            status: .notStarted,
            completionPercentage: 0.0,
            sections: [
                LessonSection(id: UUID(), heading: "What is GFCI?", body: "A Ground Fault Circuit Interrupter detects small current imbalances (as low as 5mA) and trips within 1/40th of a second — fast enough to prevent electrocution.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Where GFCI is Required", body: "NEC 210.8 requires GFCI protection in: bathrooms, garages, outdoors, crawl spaces, unfinished basements, kitchens within 6 feet of sinks, boathouses, and more.", type: .callout, necCode: "210.8"),
                LessonSection(id: UUID(), heading: "Exam Tip", body: "Memorize the locations requiring GFCI protection under 210.8. This is one of the most frequently tested NEC topics on both apprentice and master exams.", type: .callout)
            ],
            necReferences: [
                NECReference(id: UUID(), code: "210.8", title: "GFCI Protection", summary: "GFCI protection is required for personnel in specified locations including bathrooms, garages, and outdoor areas.", expanded: nil)
            ]
        ),
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000012")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000002")!,
            title: "AFCI Protection Requirements",
            topic: "NEC 210.12",
            estimatedMinutes: 10,
            status: .notStarted,
            completionPercentage: 0.0,
            sections: [
                LessonSection(id: UUID(), heading: "What is AFCI?", body: "An Arc Fault Circuit Interrupter detects dangerous arc faults — irregular electrical discharges that can cause fires — and interrupts the circuit before a fire can start.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Where AFCI is Required", body: "NEC 210.12 requires AFCI protection in all 120V, 15A and 20A branch circuits supplying outlets in dwelling unit bedrooms, family rooms, dining rooms, living rooms, and more.", type: .callout, necCode: "210.12")
            ],
            necReferences: [
                NECReference(id: UUID(), code: "210.12", title: "AFCI Protection", summary: "Arc-fault circuit-interrupter protection required for specified outlets in dwelling units.", expanded: nil)
            ]
        ),
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000013")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000002")!,
            title: "Required Outlet Placement",
            topic: "NEC 210.52",
            estimatedMinutes: 12,
            status: .notStarted,
            completionPercentage: 0.0,
            sections: [
                LessonSection(id: UUID(), heading: "Receptacle Spacing Rule", body: "Under NEC 210.52(A), receptacles must be placed so no point along a wall is more than 6 feet from a receptacle. This means receptacles every 12 feet maximum.", type: .callout, necCode: "210.52"),
                LessonSection(id: UUID(), heading: "Kitchen Countertop Placement", body: "Kitchen countertop receptacles must be placed so no point is more than 24 inches from a receptacle. Two or more circuits are required for countertop outlets.", type: .paragraph)
            ],
            necReferences: [
                NECReference(id: UUID(), code: "210.52", title: "Dwelling Unit Receptacle Requirements", summary: "Specifies minimum receptacle placement requirements for dwelling units.", expanded: nil)
            ]
        )
    ]

    static let groundingLessons: [WWLesson] = [
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000020")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000003")!,
            title: "Grounding vs. Bonding",
            topic: "NEC Article 250",
            estimatedMinutes: 10,
            status: .notStarted,
            completionPercentage: 0.0,
            sections: [
                LessonSection(id: UUID(), heading: "Grounding", body: "Grounding connects electrical equipment to the earth. Purpose: limit voltage imposed by lightning surges and provide a reference voltage for the system.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Bonding", body: "Bonding connects metal parts to ensure they are at the same potential. Purpose: prevent dangerous voltage differences between metallic surfaces that people might touch simultaneously.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Key Distinction for the Exam", body: "Grounding = connected to earth. Bonding = connected to each other. They serve different purposes and must not be confused on your exam.", type: .callout)
            ],
            necReferences: [
                NECReference(id: UUID(), code: "250.2", title: "Definitions — Grounding & Bonding", summary: "Definitions of grounding, bonding, and related terms under NEC Article 250.", expanded: nil)
            ]
        )
    ]

    static let wiringLessons: [WWLesson] = [
        WWLesson(
            id: UUID(uuidString: "00000002-0000-0000-0000-000000000030")!,
            moduleId: UUID(uuidString: "00000001-0000-0000-0000-000000000004")!,
            title: "Wire Gauge & Ampacity",
            topic: "NEC Table 310.16",
            estimatedMinutes: 12,
            status: .notStarted,
            completionPercentage: 0.0,
            sections: [
                LessonSection(id: UUID(), heading: "AWG Wire Gauge System", body: "American Wire Gauge (AWG) — counterintuitively, smaller numbers = larger wire. 14 AWG is smaller than 12 AWG. Larger wire = lower resistance = higher ampacity.", type: .paragraph),
                LessonSection(id: UUID(), heading: "Common Residential Wire Sizes", body: "• 14 AWG → 15A circuits\n• 12 AWG → 20A circuits\n• 10 AWG → 30A circuits\n• 8 AWG → 40A circuits\n• 6 AWG → 55A circuits", type: .callout)
            ],
            necReferences: [
                NECReference(id: UUID(), code: "310.16", title: "Ampacity of Conductors", summary: "Table 310.16 provides conductor ampacity for 60°C, 75°C, and 90°C rated conductors.", expanded: nil)
            ]
        )
    ]

    // MARK: - Quiz Questions

    static let sampleQuestions: [QuizQuestion] = [
        QuizQuestion(
            id: UUID(),
            question: "According to Ohm's Law, if a circuit has a resistance of 12 ohms and a voltage of 120V, what is the current?",
            choices: ["A": "10A", "B": "12A", "C": "1440A", "D": "1008A"],
            correctChoice: "A",
            explanation: "Using Ohm's Law: I = V ÷ R = 120V ÷ 12Ω = 10A. Remember: V = IR, so I = V/R.",
            topics: ["fundamentals", "ohms-law"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Under NEC 210.8, GFCI protection is required for receptacles installed in which of the following locations?",
            choices: ["A": "Bedrooms only", "B": "Bathrooms, garages, and outdoor areas", "C": "Living rooms and hallways", "D": "Only areas within 10 feet of water"],
            correctChoice: "B",
            explanation: "NEC 210.8 requires GFCI protection in bathrooms, garages, outdoors, crawl spaces, unfinished basements, kitchens within 6 feet of sinks, and other wet/damp locations.",
            topics: ["nec", "gfci", "branch-circuits"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "What is the maximum standard branch circuit rating per NEC 210.3?",
            choices: ["A": "20A", "B": "30A", "C": "50A", "D": "60A"],
            correctChoice: "C",
            explanation: "NEC 210.3 lists standard branch circuit ratings as 15, 20, 30, 40, and 50 amperes. The maximum standard rating is 50A.",
            topics: ["nec", "branch-circuits"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "A 12 AWG copper conductor has a maximum ampacity of how many amperes when installed in a raceway (NEC Table 310.16, 75°C column)?",
            choices: ["A": "15A", "B": "20A", "C": "25A", "D": "30A"],
            correctChoice: "B",
            explanation: "Per NEC Table 310.16, 12 AWG copper at 75°C has an ampacity of 20A. This is why 20A branch circuits use 12 AWG wire.",
            topics: ["wiring-methods", "ampacity"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Under NEC 210.52(A), receptacles in a dwelling unit must be placed so that no point along the floor line is more than how many feet from a receptacle outlet?",
            choices: ["A": "4 feet", "B": "6 feet", "C": "8 feet", "D": "12 feet"],
            correctChoice: "B",
            explanation: "NEC 210.52(A) requires receptacles so no point along a wall is more than 6 feet from an outlet. This effectively means receptacles every 12 feet maximum.",
            topics: ["nec", "branch-circuits", "receptacles"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "What is the primary purpose of bonding per NEC Article 250?",
            choices: [
                "A": "To connect equipment to the earth",
                "B": "To ensure metal parts are at the same electrical potential",
                "C": "To provide a path for lightning surges",
                "D": "To increase circuit ampacity"
            ],
            correctChoice: "B",
            explanation: "Bonding ensures metal parts are at the same potential to prevent dangerous voltage differences. Grounding (connecting to earth) is a separate function from bonding.",
            topics: ["grounding", "bonding"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Power in a circuit is calculated using which formula?",
            choices: ["A": "P = V + I", "B": "P = V / I", "C": "P = V × I", "D": "P = V × R"],
            correctChoice: "C",
            explanation: "Power (P) = Voltage (V) × Current (I). This is the basic power formula. You can also derive P = I²R or P = V²/R using Ohm's Law.",
            topics: ["fundamentals"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "AFCI protection is required under NEC 210.12 for branch circuits supplying outlets in dwelling unit:",
            choices: ["A": "Bathrooms only", "B": "Garages and attics", "C": "All habitable rooms including bedrooms and living areas", "D": "Kitchen and laundry areas only"],
            correctChoice: "C",
            explanation: "NEC 210.12 requires AFCI protection for 120V 15A and 20A circuits in dwelling unit bedrooms, family rooms, dining rooms, living rooms, parlors, libraries, dens, sun rooms, recreation rooms, closets, hallways, and similar areas.",
            topics: ["nec", "afci", "branch-circuits"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "In American Wire Gauge (AWG), which conductor has the LARGEST cross-sectional area?",
            choices: ["A": "14 AWG", "B": "12 AWG", "C": "10 AWG", "D": "8 AWG"],
            correctChoice: "D",
            explanation: "In AWG, smaller numbers = larger wire. 8 AWG has a larger cross-section than 10, 12, or 14 AWG. This counterintuitive system is a common exam question.",
            topics: ["wiring-methods", "conductors"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "A circuit has a resistance of 20 ohms and draws 6A of current. What is the voltage?",
            choices: ["A": "120V", "B": "240V", "C": "26V", "D": "3.3V"],
            correctChoice: "A",
            explanation: "V = I × R = 6A × 20Ω = 120V. This is a direct application of Ohm's Law (V = IR).",
            topics: ["fundamentals", "ohms-law"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "A 240V load consumes 12,000 watts. What is the current draw?",
            choices: ["A": "25A", "B": "50A", "C": "100A", "D": "40A"],
            correctChoice: "B",
            explanation: "I = P ÷ V = 12,000W ÷ 240V = 50A. This is the direct application of the power formula P = V × I rearranged to I = P/V.",
            topics: ["fundamentals"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Per NEC 110.26(A)(1) Condition 1, what is the minimum working clearance in front of a 120V panelboard when grounded parts are present on the opposite side?",
            choices: ["A": "2 feet", "B": "2.5 feet", "C": "3 feet", "D": "4 feet"],
            correctChoice: "C",
            explanation: "NEC 110.26(A)(1) requires a minimum of 3 feet (900mm) of working clearance for voltages from 0–150V under Condition 1 (exposed live parts on one side, grounded or no parts on the other).",
            topics: ["nec", "working-clearance"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Under NEC 240.4(D), what is the maximum overcurrent protection allowed for a 14 AWG copper conductor?",
            choices: ["A": "10A", "B": "15A", "C": "20A", "D": "25A"],
            correctChoice: "B",
            explanation: "NEC 240.4(D) limits 14 AWG copper conductors to a maximum of 15A overcurrent protection. This protects the conductor from overheating; 12 AWG is limited to 20A.",
            topics: ["nec", "conductors", "wiring-methods"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Per NEC Table 310.15(C)(1), what derating factor applies when 7–9 current-carrying conductors are installed in a single raceway?",
            choices: ["A": "50%", "B": "60%", "C": "70%", "D": "80%"],
            correctChoice: "C",
            explanation: "When 7–9 current-carrying conductors are in the same raceway, the ampacity must be derated to 70% of the tabulated value. Four to six conductors = 80%; ten to twenty = 50%.",
            topics: ["wiring-methods", "ampacity", "conduit"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "What is the ampacity of a 6 AWG copper conductor in a conduit at 60°C, per NEC Table 310.16?",
            choices: ["A": "40A", "B": "55A", "C": "65A", "D": "75A"],
            correctChoice: "B",
            explanation: "Per NEC Table 310.16, 6 AWG copper at 60°C has an ampacity of 55A. At 75°C it is 65A and at 90°C it is 75A. Terminal ratings typically limit you to the 60°C column.",
            topics: ["wiring-methods", "ampacity"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Per NEC Table 250.122, what is the minimum copper equipment grounding conductor (EGC) size for a circuit protected by a 20A overcurrent device?",
            choices: ["A": "14 AWG", "B": "12 AWG", "C": "10 AWG", "D": "8 AWG"],
            correctChoice: "B",
            explanation: "NEC Table 250.122 requires a minimum 12 AWG copper EGC for circuits protected by overcurrent devices rated up to 20A. For 15A protection, 14 AWG copper is permitted.",
            topics: ["grounding", "bonding"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Per NEC Table 430.52, what is the maximum rating of an inverse time circuit breaker for branch circuit short-circuit and ground-fault protection of a Design B squirrel-cage induction motor?",
            choices: ["A": "125%", "B": "175%", "C": "250%", "D": "400%"],
            correctChoice: "C",
            explanation: "NEC Table 430.52 permits inverse time circuit breakers up to 250% of the motor's full-load current for Design B squirrel-cage motors. For Design E motors, this may be up to 400% if needed.",
            topics: ["nec", "motors"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Under NEC 334.10, non-metallic sheathed cable (NM cable / Romex) is NOT permitted to be installed in which of the following?",
            choices: ["A": "One-family dwellings", "B": "Concrete block construction", "C": "Multi-family dwellings up to 3 floors", "D": "Buildings over 3 stories in height above grade"],
            correctChoice: "D",
            explanation: "NEC 334.10 permits NM cable in one- and two-family dwellings, multi-family dwellings not exceeding 3 floors above grade, and other structures per NEC 334.10(B). Buildings over 3 stories require other wiring methods.",
            topics: ["wiring-methods", "nec"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Per NEC 408.4(A), what information MUST be legibly marked on a circuit directory in a panelboard?",
            choices: ["A": "Wire size and circuit breaker brand", "B": "Date of installation and installer name", "C": "Clear, evident, and specific purpose or use of each circuit", "D": "Voltage rating and maximum load in watts"],
            correctChoice: "C",
            explanation: "NEC 408.4(A) requires that all circuits and modifications be legibly identified as to their clear, evident, and specific purpose or use. A vague description like 'lights' does not satisfy this requirement.",
            topics: ["nec", "panelboards"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Per NEC 210.52(C)(1), no point along a kitchen countertop wall space shall be more than how many inches from a receptacle outlet?",
            choices: ["A": "12 inches", "B": "18 inches", "C": "24 inches", "D": "36 inches"],
            correctChoice: "C",
            explanation: "NEC 210.52(C)(1) requires receptacles to be positioned so no point along the wall at counter level is more than 24 inches from a receptacle. This is stricter than the 6-foot (72-inch) rule for general wall space.",
            topics: ["nec", "branch-circuits", "receptacles"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "For a 200A residential service using 3/0 AWG copper service-entrance conductors, what is the minimum copper grounding electrode conductor (GEC) size per NEC Table 250.66?",
            choices: ["A": "6 AWG", "B": "4 AWG", "C": "2 AWG", "D": "1/0 AWG"],
            correctChoice: "B",
            explanation: "Per NEC Table 250.66, service-entrance conductors of 1/0 through 3/0 AWG copper require a minimum 4 AWG copper GEC. For conductors larger than 3/0 AWG up to 350 kcmil, 2 AWG is required.",
            topics: ["grounding", "bonding", "nec"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "What minimum burial depth is required for a residential branch circuit wiring method using rigid metal conduit (RMC), per NEC Table 300.5?",
            choices: ["A": "6 inches", "B": "12 inches", "C": "18 inches", "D": "24 inches"],
            correctChoice: "A",
            explanation: "NEC Table 300.5 requires a minimum cover of 6 inches for rigid metal conduit (RMC) and intermediate metal conduit (IMC) in residential applications. Direct-buried conductors without conduit require 24 inches.",
            topics: ["wiring-methods", "nec"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Under NEC 210.19(A)(1), conductors supplying a continuous load must have an ampacity not less than what percentage of the continuous load?",
            choices: ["A": "100%", "B": "110%", "C": "115%", "D": "125%"],
            correctChoice: "D",
            explanation: "NEC 210.19(A)(1) requires that branch circuit conductors have an ampacity not less than 125% of the continuous load plus 100% of the non-continuous load. Continuous loads are those expected to continue for 3 hours or more.",
            topics: ["nec", "branch-circuits", "conductors"]
        ),
        QuizQuestion(
            id: UUID(),
            question: "Per NEC 230.24(B)(1), what is the minimum clearance required for service drop conductors over a public road or alley subject to truck traffic?",
            choices: ["A": "12 feet", "B": "15 feet", "C": "18 feet", "D": "20 feet"],
            correctChoice: "C",
            explanation: "NEC 230.24(B)(1) requires service drop conductors to have a minimum clearance of 18 feet above public roads, alleys, and driveways subject to truck traffic. Residential driveways require only 12 feet.",
            topics: ["nec", "service-entrance"]
        )
    ]

    // MARK: - NEC References

    static let necReferences: [NECSearchResult] = [
        NECSearchResult(id: UUID(), code: "210.8", title: "GFCI Protection for Personnel", summary: "Ground-fault circuit-interrupter protection required in specified locations including bathrooms, garages, outdoors, crawl spaces, and kitchen countertops."),
        NECSearchResult(id: UUID(), code: "210.12", title: "AFCI Protection", summary: "Arc-fault circuit-interrupter protection required for 120V, 15A and 20A branch circuits in dwelling unit habitable rooms."),
        NECSearchResult(id: UUID(), code: "210.52", title: "Dwelling Unit Receptacle Requirements", summary: "Minimum receptacle placement requirements: no point along wall more than 6 feet from receptacle; countertops within 24 inches."),
        NECSearchResult(id: UUID(), code: "250.2", title: "Definitions (Grounding & Bonding)", summary: "Authoritative definitions for grounding, bonding, ground fault, and related terms used throughout Article 250."),
        NECSearchResult(id: UUID(), code: "250.50", title: "Grounding Electrode System", summary: "Requirements for the grounding electrode system, including metal underground water pipe, metal frame of building, concrete-encased electrode, and ground ring."),
        NECSearchResult(id: UUID(), code: "310.16", title: "Conductor Ampacity Table", summary: "Ampacity of insulated conductors for 60°C, 75°C, and 90°C temperature ratings in raceway or cable."),
        NECSearchResult(id: UUID(), code: "230.70", title: "Service Disconnecting Means", summary: "Location requirements for service disconnecting means — must be installed at a readily accessible location inside or outside the structure."),
        NECSearchResult(id: UUID(), code: "408.36", title: "Overcurrent Protection in Panelboards", summary: "Panelboards must be protected by overcurrent devices. Maximum of 42 overcurrent devices per panelboard."),
        NECSearchResult(id: UUID(), code: "700.12", title: "Emergency System Power Sources", summary: "Acceptable power sources for emergency systems including storage batteries, generator sets, and UPS."),
        NECSearchResult(id: UUID(), code: "110.26", title: "Spaces About Electrical Equipment", summary: "Working space, headroom, and dedicated equipment space requirements for electrical panels and equipment.")
    ]

    // MARK: - Progress

    static let progressSummary = ProgressSummary(
        continueLearning: ProgressSummary.ContinueLearning(
            lessonId: WattWiseContentRuntimeAdapter.uuid(for: "lesson:ap-les-004"),
            lessonTitle: "Shock Paths, PPE, and Lockout Mindset",
            progress: 0.55,
            moduleTitle: "Basic Safety (OSHA and NFPA 70E)"
        ),
        dailyGoal: ProgressSummary.DailyGoal(minutesCompleted: 18, targetMinutes: 30),
        streakDays: 4,
        recommendedAction: "Finish Shock Paths, PPE, and Lockout Mindset to lock in safety fundamentals"
    )

    // MARK: - NEC Expanded Text (keyed by code)

    static let necExpandedText: [String: String] = [
        "210.8": "NEC 210.8 requires GFCI protection for all 125-volt, single-phase, 15A and 20A receptacles in bathrooms, garages, outdoors, crawl spaces, unfinished basements, kitchen countertop surfaces, boathouses, and other wet or damp locations. GFCI devices trip when they detect a ground fault current of 4–6 milliamperes, well below the ventricular fibrillation threshold. For exam purposes, memorize all listed locations — bathrooms, garages, outdoors, crawl spaces, unfinished basements, and kitchen countertops within 6 feet of a sink are the most frequently tested.",
        "210.12": "NEC 210.12 requires AFCI protection for all 120-volt, 15A and 20A branch circuits supplying outlets in dwelling unit bedrooms, family rooms, dining rooms, living rooms, parlors, libraries, dens, sunrooms, recreation rooms, closets, hallways, and similar rooms. AFCI breakers detect the irregular electrical signature of dangerous arc faults — the leading cause of residential electrical fires. Unlike GFCI, which protects against shock, AFCI protects against fire. Combination-type AFCI breakers are required, which protect against both parallel and series arcs.",
        "210.52": "NEC 210.52 specifies minimum receptacle placement for dwelling units. Under 210.52(A), receptacles must be placed so no point along the floor line of any wall space is more than 6 feet from an outlet — effectively requiring receptacles every 12 feet maximum. Kitchen countertops require receptacles every 24 inches. Bathroom receptacles must be within 3 feet of the outside edge of each basin. Island and peninsular countertops each require at least one receptacle.",
        "250.2": "NEC Article 250 defines grounding as connecting equipment to the earth to establish a reference voltage and limit voltage imposed by lightning or line surges. Bonding is the connection of metal parts to ensure they are at the same electrical potential, preventing dangerous voltage differences between surfaces a person might touch simultaneously. These are distinct functions: grounding protects against external surges; bonding protects against internal fault currents and touch-voltage hazards.",
        "250.50": "NEC 250.50 requires that all grounding electrodes present at each building be bonded together to form the grounding electrode system. Electrodes include: metal underground water pipe in contact with the earth for 10 feet or more, the metal frame of a building, concrete-encased electrodes (Ufer grounds), ground rings, rod and pipe electrodes, and plate electrodes. If none of these are available, one or more of the listed made electrodes must be installed.",
        "310.16": "NEC Table 310.16 provides the ampacity of insulated conductors rated 0–2000V in raceway or cable based on 60°C, 75°C, and 90°C temperature ratings. Key values for 75°C copper: 14 AWG = 20A, 12 AWG = 25A, 10 AWG = 35A, 8 AWG = 50A, 6 AWG = 65A. In practice, conductors are typically limited to the 60°C column (14 AWG = 15A, 12 AWG = 20A, 10 AWG = 30A) unless terminals are rated for 75°C. This table is one of the most heavily tested references on licensing exams.",
        "230.70": "NEC 230.70 requires that the service disconnecting means be installed at a readily accessible location either outside the building or inside nearest the point of service entrance. It must be marked to indicate whether it is in the open or closed position. The disconnect must be rated for the service load and must simultaneously disconnect all ungrounded service entrance conductors. No more than six service disconnects are permitted at one location.",
        "408.36": "NEC 408.36 requires that panelboards be individually protected on the supply side by an overcurrent device. The overcurrent protection rating must not exceed the ampere rating of the panelboard bus. A maximum of 42 overcurrent devices are permitted in a single panelboard. Lighting and appliance branch-circuit panelboards require main overcurrent protection; power panelboards with less than 10% of their circuits rated at 30A or less are exempt from the individual main protection requirement.",
        "700.12": "NEC 700.12 lists acceptable power sources for legally required emergency systems, which must be capable of supplying full load within 10 seconds of normal power failure. Acceptable sources include: storage batteries, generator sets, uninterruptible power supplies (UPS), separate service, and connection ahead of the main disconnect. Emergency systems must be tested under load at least monthly (brief) and annually (full), with written records maintained. Common applications include egress lighting, exit signs, and fire alarm systems.",
        "110.26": "NEC 110.26 establishes working space requirements around electrical equipment for safe operation and maintenance. For 0–150V equipment, minimum depth is 3 feet; for 151–600V, up to 4 feet is required depending on conditions. Minimum width is 30 inches or the equipment width, whichever is greater. Minimum headroom is 6.5 feet. Dedicated electrical space must be maintained from floor to structural ceiling, and no piping, ducts, or leak-prone equipment may be installed above panelboards. These clearances are heavily tested on apprentice and journeyman exams."
    ]

    // MARK: - Tutor Responses

    static func tutorResponse(for message: String) -> TutorMessage {
        TutorMessage(
            id: UUID(),
            content: "Great question! Let me break this down step by step.",
            role: .assistant,
            timestamp: Date(),
            steps: [
                "First, identify the values given (voltage, current, or resistance).",
                "Apply the appropriate formula: V = IR, I = V/R, or R = V/I.",
                "Double-check your units — always work in volts, amps, and ohms.",
                "Verify your answer makes practical sense for the circuit."
            ],
            followUps: [
                "Can you show me a practice problem?",
                "How does this apply to a 240V circuit?",
                "What happens if resistance changes?"
            ]
        )
    }
}

// MARK: - US States for onboarding

extension MockData {
    static let usStates: [(abbreviation: String, name: String)] = [
        ("AL", "Alabama"), ("AK", "Alaska"), ("AZ", "Arizona"), ("AR", "Arkansas"),
        ("CA", "California"), ("CO", "Colorado"), ("CT", "Connecticut"), ("DE", "Delaware"),
        ("FL", "Florida"), ("GA", "Georgia"), ("HI", "Hawaii"), ("ID", "Idaho"),
        ("IL", "Illinois"), ("IN", "Indiana"), ("IA", "Iowa"), ("KS", "Kansas"),
        ("KY", "Kentucky"), ("LA", "Louisiana"), ("ME", "Maine"), ("MD", "Maryland"),
        ("MA", "Massachusetts"), ("MI", "Michigan"), ("MN", "Minnesota"), ("MS", "Mississippi"),
        ("MO", "Missouri"), ("MT", "Montana"), ("NE", "Nebraska"), ("NV", "Nevada"),
        ("NH", "New Hampshire"), ("NJ", "New Jersey"), ("NM", "New Mexico"), ("NY", "New York"),
        ("NC", "North Carolina"), ("ND", "North Dakota"), ("OH", "Ohio"), ("OK", "Oklahoma"),
        ("OR", "Oregon"), ("PA", "Pennsylvania"), ("RI", "Rhode Island"), ("SC", "South Carolina"),
        ("SD", "South Dakota"), ("TN", "Tennessee"), ("TX", "Texas"), ("UT", "Utah"),
        ("VT", "Vermont"), ("VA", "Virginia"), ("WA", "Washington"), ("WV", "West Virginia"),
        ("WI", "Wisconsin"), ("WY", "Wyoming")
    ]
}
