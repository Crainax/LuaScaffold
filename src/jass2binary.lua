-- Intentional project-local override for the pinned engine's optional auto-require.
-- Plain JASS boot maps must not execute the workstation's legacy protection tool.
require('jass.console').enable = false
package.console_enable = false
return true
