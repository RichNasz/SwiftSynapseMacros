// Generated from CodeGenSpecs/Shared-Skills.md — Do not edit manually. Update spec and re-generate.

import Foundation
import SwiftOpenSkills
import SwiftOpenResponsesDSL

/// Re-export skills types for convenience.
public typealias SkillStore = SwiftOpenSkills.SkillStore
public typealias SkillSearchPath = SwiftOpenSkills.SkillSearchPath
public typealias Skill = SwiftOpenSkills.Skill

#if canImport(SwiftOpenSkillsResponses)
import SwiftOpenSkillsResponses

/// Re-export skills-responses types for convenience.
public typealias SkillsAgent = SwiftOpenSkillsResponses.SkillsAgent
public typealias Skills = SwiftOpenSkillsResponses.Skills
#endif
