## Purpose

Presents everything Magunetto says to a user in that user's own language, and states what a
translation must satisfy before it is fit to ship. The gesture itself is wordless; this covers the
preferences dialog, which is the only place the extension uses language at all.

## ADDED Requirements

### Requirement: Displayed text is presented in the session's language

Every string the preferences dialog displays SHALL be translatable, and SHALL be presented from the
catalogue that matches the session's language. Where no catalogue matches, the source language
SHALL be presented instead. Presentation SHALL NOT depend on how the extension was installed.

#### Scenario: Session language has a catalogue

- **WHEN** the preferences dialog is opened in a language that has a catalogue
- **THEN** every string it displays is presented in that language

#### Scenario: Session language has no catalogue

- **WHEN** the preferences dialog is opened in a language that has no catalogue
- **THEN** every string it displays is presented in the source language
- **AND** no string is blank, and none shows an internal identifier

#### Scenario: Session names a region with no catalogue of its own

- **WHEN** the session language names a region for which no separate catalogue exists, and a
  catalogue exists for the language
- **THEN** the language's catalogue is presented

#### Scenario: Extension installed from a packaged artefact

- **WHEN** the extension is installed from any artefact the project publishes
- **THEN** its catalogues are present and resolve

### Requirement: The source language is British English

Strings SHALL be authored in British English, and that SHALL be what a user sees when no catalogue
matches. American English SHALL be offered as a catalogue like any other language, not as the
source.

#### Scenario: A string differs between the two

- **WHEN** a string is spelled differently in British and American English
- **THEN** a session in American English presents the American spelling
- **AND** a session in any language with no catalogue presents the British spelling

### Requirement: The catalogue template covers every displayed string

The catalogue template SHALL contain every string the preferences dialog can display, including
those the extension carries as data rather than writing inline. Adding a string SHALL NOT be
possible without it appearing in the template.

#### Scenario: A travel style is added

- **WHEN** a new travel style is added, with a name and a description
- **THEN** both appear in the catalogue template

#### Scenario: The template has drifted from the source

- **WHEN** the template does not account for every string the dialog can display
- **THEN** this is reported as a failure

### Requirement: A shipped catalogue is complete

A catalogue SHALL translate every string in the template, and SHALL carry no entry marked as
needing review. A catalogue that does not SHALL NOT ship: presenting a half-translated dialog is
worse than presenting an English one, because the gaps read as bugs rather than as an absent
translation.

#### Scenario: A catalogue leaves a string untranslated

- **WHEN** a catalogue does not translate every string in the template
- **THEN** this is reported as a failure

#### Scenario: A catalogue marks an entry as needing review

- **WHEN** a catalogue carries an entry marked as needing review
- **THEN** this is reported as a failure

### Requirement: Translated travel styles stay distinguishable

The travel styles are chosen from a single list and are told apart only by what they are called, so
in every catalogue their names SHALL be distinct from one another. Each style's description SHALL
remain a single sentence, closed by whatever punctuation closes a sentence in that language.

#### Scenario: Two styles are given the same name

- **WHEN** a catalogue translates two travel styles to the same name
- **THEN** this is reported as a failure

#### Scenario: A description is not a sentence

- **WHEN** a catalogue's translation of a style description does not close as a sentence in that
  language
- **THEN** this is reported as a failure

### Requirement: Stored values are never translated

Text that names a value the extension stores or reads SHALL appear unchanged in every catalogue.
Translating it would describe a setting the extension cannot accept.

#### Scenario: A setting's description names its permitted values

- **WHEN** a setting's description lists the values that setting accepts
- **THEN** those values appear unchanged in every catalogue

### Requirement: The region menu conveys its selection without language

The radial menu SHALL convey which region is selected by shape and position alone, and SHALL
display no text. It is presented for the length of a gesture, over a pointer that is already
moving, and it must be equally readable to a user whose language is not translated at all.

#### Scenario: The menu is raised in any language

- **WHEN** the menu is raised
- **THEN** it displays no text
- **AND** the selected region is distinguishable from the unselected ones
