# CLAUDE.md - LifeOps Project Guide

This file provides guidance to Claude Code when working on the LifeOps project.

## Project Overview

**LifeOps** is a unified personal life management system designed to:
- Control all aspects of private life and home from ONE app
- Provide gamification with personal stats that actually improve habits
- Unify multiple device ecosystems (Apple, Google, Samsung, Plejd, Oura)
- Be privacy-first with secure, CPU-efficient, fast communication

## Key Documentation

| File | Purpose |
|------|---------|
| `VISION.md` | Core philosophy, goals, problems to solve |
| `DEVICES.md` | Hardware inventory and ecosystems |
| `SERVICES.md` | Subscriptions, apps, integrations |
| `ROUTINES.md` | Daily patterns and habit goals |
| `AGENTS.md` | Life domain agent definitions |
| `ARCHITECTURE.md` | Technical architecture (to be created) |
| `GAMIFICATION.md` | Game mechanics design (to be created) |

## Agent System

LifeOps uses a collaborative agent system for architecture, design, and implementation. All agents are in `.claude/commands/`.

### Main Orchestrator
- **`/architect`** - Chief Architect that coordinates all specialists

### Architecture & Design Agents
| Command | Role |
|---------|------|
| `/backend` | Infrastructure, databases, APIs, self-hosting |
| `/frontend` | Cross-platform UI, unified app strategy |
| `/gamification` | XP systems, habit mechanics, motivation (high-level) |
| `/integrations` | Device ecosystems, smart home, APIs |
| `/habits` | Evidence-based behavior change, psychology |
| `/security` | Encryption, secure communication, privacy |

### Implementation Agents
| Command | Role |
|---------|------|
| `/fastapi-expert` | FastAPI patterns, async Python, Pydantic |
| `/database-architect` | PostgreSQL/TimescaleDB schema, queries, indexes |
| `/python-reviewer` | Code review, security, best practices |
| `/rpg-systems` | RPG progression mechanics, skill trees, balance |
| `/service-integrator` | Microservice communication, contracts, resilience |
| `/timeline-architect` | Timeline/routine scheduling, streaks, completion logic |
| `/health-data-specialist` | Oura API, health metrics, time-series data |
| `/testing-engineer` | pytest, fixtures, async testing, coverage |
| `/devops-specialist` | Docker, compose, local dev, deployment |

### LifeOps Management Agents
| Command | Role |
|---------|------|
| `/setup` | Initialize LifeOps areas |
| `/task` | Manage tasks and projects |
| `/goals` | Track personal/professional goals |
| `/review` | Periodic system reviews |

### How to Use Agents

1. **Run the architect** to coordinate full architecture:
   ```
   /architect Design the complete LifeOps architecture
   ```

2. **Consult implementation specialists** for code work:
   ```
   /fastapi-expert Review the timeline router implementation
   /database-architect Design the schema for activity tracking
   /testing-engineer Create tests for the gamification service
   ```

3. **Use domain specialists** for focused questions:
   ```
   /rpg-systems Balance the XP curve for stat progression
   /health-data-specialist Optimize Oura API sync strategy
   ```

4. **Architect consults specialists** automatically for major decisions

## Critical Requirements

All technical decisions must satisfy:
- **Secure** - All device communication encrypted
- **CPU Efficient** - Runs on Raspberry Pi or always-on device
- **Fast** - Low latency for real-time control
- **Private** - All data under user control, self-hosted
- **Unified** - ONE app for all platforms

## User Context

- Technical user, comfortable with programming
- Uses AI-assisted development (Claude Code)
- Willing to buy equipment for unified experience
- Values function over polish

## Development Status

**Phase: Active Development**
- Vision documented
- Device inventory complete
- Agent system: 20 agents covering all domains
- Architecture: Backend services running

### Services Implemented
| Service | Port | Status |
|---------|------|--------|
| `lifeops-api` | 8000 | Active - Main API |
| `stats-api` | 8001 | Active - RPG stats |
| `timescaledb` | 5432 | Active - Health data |
| `stats-db` | 5433 | Active - Character data |

### Key Features Built
- Oura Ring integration and sync
- Gamification engine (Life Score, XP, levels)
- Timeline/routine system with streaks
- Character stats and skill tree engine
- Activity logging and progression

## Next Steps

1. Add comprehensive test coverage (`/testing-engineer`)
2. Review and optimize existing code (`/python-reviewer`)
3. Complete frontend strategy (`/frontend`)
4. Set up CI/CD pipeline (`/devops-specialist`)
