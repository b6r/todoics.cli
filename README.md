#OVERVIEW#
todoics.cli ist created to serve as a command line todo application that works with iCalender files as the todo database, so that you can synchronise todos with your iCalender server of your choice (like owncloud). It is heavily inspired by Gina Trapani's [todo.txt.cli](https://github.com/ginatrapani/todo.txt-cli "todo.txt-cli on github") and works fine together with [vdirsyncer](https://github.com/untitaker/vdirsyncer "vdirsyncer on github") to do the synchronisation. Right now it only uses a part of the properties defined in the iCalender specification, but it is intended to add all standard properties in future versions.

The main idea behind this project is to have a command line tool that is easy to use. It is able to create new todos, to modify and delete them. 

Hint: This is a very early version of todoics.cli. 


#INSTALL#
To install todoics.cli just copy the perl file into a directory in your path. It expects a config file in the directory ~/.config/todoics.cli. It the directory does not exist please create it and copy the file todoicscli.conf into it. You have to change the value of icsFile before you can start, which points to the directory where your .ics files are stored (where vdirsyncer stores it). For the cache file please create ~/.local/todoics.cli.


#USAGE#
You create a new todo by calling the script with the parameter -n or --new.

    todoics.cli.pl --new This is a test todo due=+1w prio=1 *testcategory_1 *testcategory2 @PRIVATE

If you create a new todo, the text behind the -n/--new will be treated as the summary of the todo. As soon as you provide a property the rest of the command line arguments will be treated as a property=value pair. 
todoics.cli.pl currently can handle the following properties:

**\*category**

By using * and a name for a category of your choice you can set 1..n categories for your todo. In modify mode you can add a category by putting a + sign in front of the category name and you can remove a category by adding a - sign.

**@class**

By using @ and class name you can set the visibility of the todo. Possible values are PRIVATE, PUBLIC and CONFIDENTIAL. The default value is PRIVATE.

**due=*date***

You can set a duedate by adding a date value to the todo. It is possible to define a date in the following formats dd.mm.yyyy, yyyymmdd, yyyymmddhhmm and yyyymmddhhmmss. It is also possible to set a date relatively to now (or a existing duedate). You can increase the duedate by year (+ny), month (+nm), week (+nw) or day (+nd). The duedate can also be decresed (-).

**prio=*prio***
If you want to define the priority of a todo you can choose a value between 0 (no priority), 1 (high priority) and 9 (low priority).


In the case of a closing (-c/--close), or a modification (-m/--modify) of a todo the first part of the command line arguments must be the id of the todo, that should be changed, and the rest is treated as a property=value pair.

    todoics.cli.pl -c 2
closes the todo with id 2.

    todoics.cli.pl -m 3 *+testcategorie_3
adds a new category to todo with id 3


**These are the implemented options:**

todoics.cli.pl [options] task description

--showall or -a: Shows all todos in the iCalendar directory.

--show or -s: Shows all open todos in the iCalendar directory.

--new or -n: Creates a new todo entry.

--close or -c: Closes the task identfied by todo number. 

--modify or -m: Modifies the task identified by todo number.

--help or -h: Shows this help.
