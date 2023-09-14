Using the "grep" Command
The grep command is a built-in Linux command that allows you to search for lines that match a given pattern. By default, it returns all lines in a file that contain a specified string. The grep command is case-sensitive, but you can use specific parameters to modify its behavior.

To search for files containing a specific text string, you can use the following command

grep -rni "text string" /path/to/directory

-r performs a recursive search within subdirectories.
-n displays the line number containing the pattern.
-i ignores the case of the text string.
The above command will display all lines in the files within the specified directory that contain the given text string, along with the corresponding line numbers.

To filter the results and display only the filenames without duplication, you can use the following command:

grep -rli "text string" /path/to/directory

-l prints only the names of the files containing the pattern.
This command will provide a list of filenames that contain the specified text string, eliminating any duplicates.


Using the "find" Command
Another useful command for searching files is find, which can be combined with grep to achieve more specific results. The find command allows you to search for files based on various criteria, such as name, type, size, and more.

To find files containing a specific text string using the find command, you can utilize the following syntax:

find /path/to/directory -type f -exec grep -l "text string" {} \;

/path/to/directory specifies the directory in which the search will be performed.
-type f filters the search to only include regular files.
-exec grep -l "text string" {} \; executes the grep command on each file found and displays the filenames that contain the text string.
This command will provide a list of filenames without duplicates that match the specified text string.