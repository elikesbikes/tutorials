sed Find and Replace Syntax
The syntax to find and replace text using the sed command is:

sed -i 's/<search regex>/<replacement>/g' <input file>

The command consists of the following:

-i tells the sed command to write the results to a file instead of standard output.
s indicates the substitute command.
/ is the most common delimiter character. The command also accepts other characters as delimiters, which is useful when the string contains forward slashes.
<search regex> is the string or regular expression search parameter.
<replacement> is the replacement text.
g is the global replacement flag, which replaces all occurrences of a string instead of just the first.
<input file> is the file where the search and replace happens.
The single quotes help avoid meta-character expansion in the shell.

The BDS version of sed (which includes macOS) does not support case-insensitive matching or file replacement. The command for file replacement looks like this:

sed 's/<search regex>/<replacement>/g' <input file> > <output file>



====================================================
Use Stream EDitor (sed) as follows:
sed -i 's/old-text/new-text/g' input.txt