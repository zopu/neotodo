# Configuration files

When processing a todo file, neotodo will search for a configuration file either in the current directory or in a parent directory.

This file will be named '.todo.json'

This config file will have a json format.

## Configuration options

We want to eventually support the following sorts of configuration options:
- *Focus mode sections*: Specifying which sections are shown in focus mode.
- *Styling*: Specifying colors, fonts, and other styling options for different sections and task states, especially in focus mode.
- *Relationships between sections*: Allowing keyboard shortcuts to move tasks between related sections e.g. from "Today" to "Tomorrow".
- *Location of "Done" file.*: Allowing the user to clean up the "Done" section into a separate file.
- *Commands to import new tasks*: This allows the user to generate new tasks from other devices or applications. This is specified with a shell command which is expected to output new tasks - one per line. These will be fetched when the user runs the "Import new tasks" command.
