# Mermaid Syntax Reference

Quick reference for each supported diagram type.

---

## flowchart

```mermaid
flowchart TD
    A[Rectangle] --> B(Rounded)
    B --> C{Diamond / Decision}
    C -->|Yes| D([Stadium])
    C -->|No| E[(Cylinder / DB)]
    D --> F((Circle))
    E --> G[[Subroutine]]
```

**Directions:** `TD` (top-down), `LR` (left-right), `BT`, `RL`

**Node shapes:**

| Shape | Syntax |
|-------|--------|
| Rectangle | `[label]` |
| Rounded | `(label)` |
| Stadium | `([label])` |
| Subroutine | `[[label]]` |
| Cylinder (DB) | `[(label)]` |
| Circle | `((label))` |
| Diamond | `{label}` |
| Hexagon | `{{label}}` |
| Trapezoid | `[/label/]` |

**Edge types:**

| Edge | Syntax |
|------|--------|
| Arrow | `-->` |
| Open | `---` |
| Dotted | `-.->` |
| Thick | `==>` |
| Labeled | `-->|text|` |
| Bidirectional | `<-->` |

**Subgraphs:**
```
subgraph name [Title]
    A --> B
end
```

---

## sequenceDiagram

```mermaid
sequenceDiagram
    participant A as Alice
    participant B as Bob
    A->>+B: Request
    B-->>-A: Response
    A-xB: Async fire-and-forget
    Note over A,B: Shared note
    rect rgb(200,220,255)
        A->>B: Highlighted block
    end
```

**Arrow types:**

| Type | Syntax | Meaning |
|------|--------|---------|
| Solid arrow | `->>` | Sync message |
| Dashed arrow | `-->>` | Response |
| Solid, no arrow | `->` | |
| Cross | `-x` | Async / fire-and-forget |
| Open | `-)` | Async |

**Activation:** `+` activates, `-` deactivates the participant lifeline.

**Loops / alt / opt:**
```
loop Every minute
    A->>B: ping
end

alt condition
    A->>B: path 1
else
    A->>B: path 2
end

opt optional
    A->>B: optional step
end
```

---

## classDiagram

```mermaid
classDiagram
    class Animal {
        +String name
        +int age
        +makeSound() void
    }
    class Dog {
        +fetch() void
    }
    Animal <|-- Dog : extends
    Dog --> Bone : has
```

**Relationships:**

| Symbol | Meaning |
|--------|---------|
| `<|--` | Inheritance |
| `*--` | Composition |
| `o--` | Aggregation |
| `-->` | Association |
| `--` | Link |
| `..>` | Dependency |
| `..|>` | Realization |

**Visibility:** `+` public, `-` private, `#` protected, `~` package/internal

**Cardinality:** `"1"`, `"0..*"`, `"1..*"` on relationship lines

---

## erDiagram

```mermaid
erDiagram
    USER {
        uuid id PK
        string email
        string name
    }
    ORDER {
        uuid id PK
        uuid user_id FK
        timestamp created_at
    }
    USER ||--o{ ORDER : places
```

**Cardinality notation:**

| Left | Right | Meaning |
|------|-------|---------|
| `||` | `||` | Exactly one to exactly one |
| `||` | `o{` | One to zero or more |
| `||` | `|{` | One to one or more |
| `o|` | `o{` | Zero or one to zero or more |

**Attribute types:** `string`, `int`, `float`, `boolean`, `uuid`, `timestamp`, `date`

**Keys:** `PK` primary key, `FK` foreign key, `UK` unique key

---

## stateDiagram-v2

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Processing : start
    Processing --> Done : success
    Processing --> Error : failure
    Error --> Idle : retry
    Done --> [*]

    state Processing {
        [*] --> Validating
        Validating --> Executing
        Executing --> [*]
    }
```

Use `state "Label with spaces" as alias` for states with special characters.

---

## gitGraph

```mermaid
gitGraph
    commit id: "init"
    branch feature/auth
    checkout feature/auth
    commit id: "add login"
    commit id: "add JWT"
    checkout main
    merge feature/auth id: "merge auth" tag: "v1.1"
    branch hotfix
    checkout hotfix
    commit id: "fix XSS"
    checkout main
    merge hotfix tag: "v1.1.1"
```

**Commit types:** `NORMAL` (default), `HIGHLIGHT`, `REVERSE`

---

## gantt

```mermaid
gantt
    title Project Timeline
    dateFormat YYYY-MM-DD
    excludes weekends

    section Backend
        API design       :done,    api,   2024-01-01, 2024-01-07
        Implementation   :active,  impl,  2024-01-08, 14d
        Testing          :         test,  after impl,  7d

    section Frontend
        UI mockups       :done,    ui,    2024-01-01, 2024-01-10
        Development      :         dev,   2024-01-11, 21d
```

**Status tags:** `done`, `active`, `crit`, `milestone`

---

## mindmap

```mermaid
mindmap
    root((Central Topic))
        Branch A
            Leaf A1
            Leaf A2
        Branch B
            Leaf B1
        Branch C
```

**Node shapes:**
- `((text))` - circle
- `(text)` - rounded
- `[text]` - square
- `{{text}}` - hexagon
- No brackets - default cloud

Note: mindmap cannot be converted to Excalidraw via `mermaid-to-excalidraw`. Use a `flowchart` equivalent if Excalidraw export is needed.

---

## C4Context (Architecture)

```mermaid
C4Context
    title System Context - Payment Service

    Person(customer, "Customer", "Makes purchases")
    System(payment, "Payment Service", "Handles transactions")
    System_Ext(bank, "Banking API", "External payment processor")

    Rel(customer, payment, "Submits payment", "HTTPS")
    Rel(payment, bank, "Processes charge", "REST/TLS")
```

**C4 element types:** `Person`, `System`, `System_Ext`, `Container`, `Component`

**Relationship:** `Rel(from, to, label)` or `Rel(from, to, label, tech)`

---

## Theme Config Reference

```yaml
---
config:
  theme: neutral          # neutral | default | dark | forest | base
  look: classic           # classic | handDrawn
  fontFamily: "monospace" # any CSS font-family
  fontSize: 14
  flowchart:
    curve: basis          # basis | linear | step | stepBefore | stepAfter
    padding: 20
  sequence:
    mirrorActors: false
    showSequenceNumbers: true
---
```

For `base` theme, custom variables are available:

```yaml
---
config:
  theme: base
  themeVariables:
    primaryColor: "#4A90D9"
    primaryTextColor: "#fff"
    primaryBorderColor: "#2C5F8A"
    lineColor: "#666"
    secondaryColor: "#F5F5F5"
    tertiaryColor: "#E8F4FD"
---
```
