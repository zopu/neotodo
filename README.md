# NeoTODO

A plugin to aid with editing of TODO.txt files in Neovim using an opinionated structure.

A todo file for this plugin is a text file with section headers (with a colon suffix) followed by an indented list of tasks.

```
New:
  something I just thought of

This week:
  thing 1
  thing 2

Top This Week:
  Most important task for this week
  Second most important task for this week

Today:
  fairly urgent job to be done

Blocked:
  A task that can't be done yet
  A task waiting on someone else

Now:
  a task I'm currently working on
  another task
```

Arbitrary sections headers are supported, but some are required and have special meaning:
- "New" - New tasks are added here by default.
- "Now" - Tasks are moved heen when started.
- "Top This Week" - Is not hidden when in a focus mode.
- "Done" - Completed tasks are moved here.

This plugin provides commands to manipulate tasks and sections, move quickly between sections, and focus/hide sections.

## Basic Commands

- "MoveToSection" - opens an fzf picker to move the cursor to a section.
- "MarkAsDone" - moves a task to the "Done" section.
- "FocusModeEnable" - hides all sections except the "Now" and "Top This Week" sections.
- "FocusModeDisable" - shows all sections again.
- "AddTask" - Adds a new line to the "New" section and places the cursor there in insert mode.

Keybinds for these commands can be set in the plugin setup. These keybinds will only be active when editing a file called TODO.txt.

