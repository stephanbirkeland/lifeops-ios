# LifeOps Agent Architecture

This document defines the intelligent agents that power LifeOps. Each agent has a specific domain of responsibility and can work autonomously or coordinate with other agents.

---

## Philosophy

Agents in LifeOps are **proactive assistants** that:
- Monitor their domain continuously
- Take action when appropriate
- Provide insights and recommendations
- Respect user autonomy (suggest, don't control)
- Learn from patterns over time

---

## Life Domain Agents

### 1. Sleep Agent
**Purpose**: Optimize sleep quality and consistency

| Responsibility | Actions |
|----------------|---------|
| Bedtime management | Remind, dim lights, wind-down mode |
| Wake optimization | Smart alarm, gradual light increase |
| Sleep tracking | Monitor duration, quality, stages |
| Pattern analysis | Identify what affects sleep |
| Recovery insights | Use readiness score for daily planning |

**Integrations**:
- **Oura Ring** (primary data source) - Sleep stages, duration, efficiency, HRV, readiness
- Plejd (lights) - Gradual dimming/brightening
- iPhone (alarm) - Wake time coordination
- All screens - Wind-down mode triggers

**Key Oura Metrics**:
- Sleep score, efficiency, timing
- Deep sleep and REM duration
- HRV trends (recovery indicator)
- Readiness score (next-day planning)

**Triggers**:
- Target bedtime approaching
- Wake time alarm
- Sleep quality declining (Oura trend)
- Low readiness score

---

### 2. Fitness Agent
**Purpose**: Support consistent exercise habits

| Responsibility | Actions |
|----------------|---------|
| Workout reminders | Morning motivation |
| Streak tracking | Maintain consistency |
| Recovery monitoring | Suggest rest days based on readiness |
| Goal progress | Track toward fitness goals |
| Intensity guidance | Adjust based on recovery |

**Integrations**:
- **Oura Ring** - Readiness score, activity tracking, recovery data
- Calendar - Gym schedule
- Apple Health - Workout data sync

**Oura-Powered Features**:
- "Your readiness is 85, great day for an intense workout"
- "Low readiness (62), consider lighter activity or rest"
- Activity goal tracking (steps, movement)
- Weekly activity trends

**Triggers**:
- Morning after wake (with readiness context)
- Missed workout detection
- Weekly summary
- Low activity alert

---

### 3. Work-Life Balance Agent
**Purpose**: Maintain healthy boundaries between work and personal time

| Responsibility | Actions |
|----------------|---------|
| Work hours tracking | Monitor actual hours worked |
| End-of-day alerts | Encourage stopping work |
| Overtime warnings | Alert when working too long |
| Break reminders | Suggest regular breaks |

**Integrations**: Calendar (all three), computer activity

**Triggers**:
- End of scheduled work day
- Extended work session detected
- Weekend/evening work

---

### 4. Screen Time Agent
**Purpose**: Reduce unnecessary screen time and digital distraction

| Responsibility | Actions |
|----------------|---------|
| Usage tracking | Monitor time on devices |
| App limits | Enforce configured limits |
| Focus modes | Enable during work/sleep |
| Pattern insights | Show where time goes |

**Integrations**: All devices (iOS Screen Time, Linux tools)

**Triggers**:
- Approaching daily limit
- Late night usage
- Excessive social media

---

### 5. Home Agent
**Purpose**: Manage smart home and household tasks

| Responsibility | Actions |
|----------------|---------|
| Lighting control | Scenes, schedules, automation |
| Climate awareness | Weather-based suggestions |
| Chore tracking | Remind about household tasks |
| Energy awareness | Optimize usage |

**Integrations**: Plejd, HomeKit, Google Home, SmartThings

**Triggers**:
- Time-based scenes (morning, evening)
- Arriving/leaving home
- Chore schedule

---

### 6. Entertainment Agent
**Purpose**: Enhance leisure time without enabling excess

| Responsibility | Actions |
|----------------|---------|
| Content suggestions | What to watch/listen |
| Binge prevention | "Last episode" warnings |
| Music automation | Right music for the moment |
| Watch history | Track across services |

**Integrations**: Netflix, HBO Max, Disney+, Spotify, Samsung TV

**Triggers**:
- Evening relaxation time
- Multiple episodes watched
- Bedtime approaching during content

---

### 7. Social Agent
**Purpose**: Maintain relationships and social health

| Responsibility | Actions |
|----------------|---------|
| Contact tracking | When did I last talk to X? |
| Event awareness | Upcoming social events |
| Communication digest | Unified message overview |
| Relationship reminders | Prompt reaching out |

**Integrations**: Calendar, messaging apps, contacts

**Triggers**:
- Long time since contacting someone
- Social events approaching
- Message digest times

---

### 8. Cabin Agent
**Purpose**: Manage cabin trips and property

| Responsibility | Actions |
|----------------|---------|
| Trip planning | Packing lists, weather |
| Travel time | Route and departure time |
| Property status | Check on cabin systems |
| Seasonal prep | Winterization, summer opening |

**Integrations**: Weather services, calendar, cabin devices

**Triggers**:
- Weekend approaching
- Weather changes at cabin
- Seasonal transitions

---

### 9. Nutrition Agent
**Purpose**: Support healthy eating and meal management

| Responsibility | Actions |
|----------------|---------|
| Meal planning | Suggest meals for the week |
| Shopping lists | Generate from meal plan |
| Recipe storage | Save and organize recipes |
| Nutrition tracking | Optional food logging |

**Integrations**: Notes/storage, shopping apps

**Triggers**:
- Weekly planning time
- Shopping day
- Mealtime

---

### 10. Finance Agent
**Purpose**: Personal finance awareness (basic)

| Responsibility | Actions |
|----------------|---------|
| Spending awareness | Track major expenses |
| Bill reminders | Upcoming payments |
| Subscription tracking | What am I paying for? |
| Budget check-ins | Periodic reviews |

**Integrations**: Banking apps (read-only), calendar

**Triggers**:
- Bill due dates
- Monthly review
- Unusual spending

---

## Technical Agents

### Integration Agent
**Purpose**: Bridge between different ecosystems and services

| Responsibility | Implementation |
|----------------|----------------|
| API management | Connect to all services |
| Data normalization | Unified data format |
| Event routing | Send events to right agents |
| Health monitoring | Ensure connections work |

**Technology**: Central service, API clients

---

### Notification Agent
**Purpose**: Intelligent notification management

| Responsibility | Implementation |
|----------------|----------------|
| Priority filtering | Only important notifications |
| Batching | Group non-urgent items |
| Channel routing | Right message to right device |
| Quiet hours | Respect do-not-disturb |

**Rules**:
- Urgent: Immediate, all devices
- Important: Phone notification
- Normal: Batched digest
- Low: Available on request

---

### Automation Agent
**Purpose**: Execute automated routines and responses

| Responsibility | Implementation |
|----------------|----------------|
| Trigger handling | Respond to events |
| Scene execution | Run multi-step automations |
| Schedule management | Time-based triggers |
| Condition evaluation | Complex rule processing |

**Examples**:
- Morning routine: Lights + alarm + music
- Bedtime: Dim lights + wind-down mode
- Leaving home: Turn off lights, lock up

---

### Data Agent
**Purpose**: Collect, store, and analyze personal data

| Responsibility | Implementation |
|----------------|----------------|
| Data collection | Gather from all sources |
| Privacy protection | Local storage, encryption |
| Pattern analysis | Find insights in data |
| Reporting | Generate summaries |

**Principles**:
- Data stays local/private
- User can export/delete anytime
- Transparent about what's collected

---

### Device Agent
**Purpose**: Manage device-specific interfaces

| Responsibility | Implementation |
|----------------|----------------|
| iOS app | iPhone/iPad interface |
| macOS app | Mac menu bar/app |
| Linux daemon | Background service |
| Web dashboard | Browser interface |
| Voice interface | Via HomePod/Google |

---

## Agent Coordination

```
┌─────────────────────────────────────────────────────────────┐
│                    LifeOps Orchestrator                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │  Sleep  │ │ Fitness │ │Work-Life│ │ Screen  │          │
│  │  Agent  │ │  Agent  │ │  Agent  │ │  Agent  │          │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘          │
│       │           │           │           │                │
│  ┌────┴───────────┴───────────┴───────────┴────┐          │
│  │            Integration Agent                 │          │
│  └────┬───────────┬───────────┬───────────┬────┘          │
│       │           │           │           │                │
│  ┌────┴────┐ ┌────┴────┐ ┌────┴────┐ ┌────┴────┐          │
│  │ Notif.  │ │ Autom.  │ │  Data   │ │ Device  │          │
│  │ Agent   │ │  Agent  │ │  Agent  │ │  Agent  │          │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Priority

### Phase 1: Foundation
1. Data Agent - Core storage and tracking
2. Integration Agent - Connect ecosystems
3. Device Agent - Basic interfaces

### Phase 2: Core Life Agents
4. Sleep Agent - Address primary pain point
5. Work-Life Balance Agent - Stop working late
6. Screen Time Agent - Reduce phone time

### Phase 3: Enhancement
7. Home Agent - Smart home unification
8. Fitness Agent - Morning routine support
9. Entertainment Agent - Controlled leisure

### Phase 4: Expansion
10. Social Agent
11. Cabin Agent
12. Nutrition Agent
13. Finance Agent

---

*Last updated: January 2025*
