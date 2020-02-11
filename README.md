# Business Central Container Script

This repository is a fork of Microsoft's NavContainerHelper repository that contains a module, which makes it easier to work with Nav Containers on Docker.

It was forked to adjust the code to be even easier to work with and adds a template-based system to create containers. This file is by default located in your user account's AppData folder but can also be on a network drive which allows for a centralized template file to be used to create containers for different projects

## How to use?

For the use of NavContainerHelper's cmdlets please refer to the original repository and it's wiki.

The BCCSAssistant is adding the following functions to the NavContainerHelper:

| Function                      | Description                                  |
|-------------------------------|----------------------------------------------|
| Get-BCCSImage                 | Returns all available images in a repository |
| Get-BCCSRepository            | Returns all templates                        |
| New-BCCSContainerFromTemplate | Creates a container from a template          |
| New-BCCSTemplate              | Creates a new template                       |
| Remove-BCCSTemplate           | Removes an existing template                 |
| Show-BCCSAssistant            | Shows a wizard to use the above commands      |

The currently most important command to know for this script is **Show-BCCSAssistant** which basically opens up a wizard that allows you to **create/remove templates**, **create containers** from those templates and and **update licenses**. This command also accepts an existing *templates.json* as a parameter to be used.

By default your *templates.json* will be created in *%AppData%\\.bccs\templates.json*
