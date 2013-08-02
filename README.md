`gitprompt` is an efficient, highly configurable prompt for Git status information in command-line shells.

To use it, attach the associated script, `gitprompt.pl`, to your shell's mechanism for running a command before the prompt is displayed (in `bash`, this is `PROMPT_COMMAND`), storing its result in `PS1` (or whatever your shell's prompt variable).  For example, in `bash`, you could put this in your `.bashrc` or `.bash_profile`:

```
# if you already have a PROMPT_COMMAND
export PROMPT_COMMAND=$PROMPT_COMMAND';export PS1=$(gitprompt.pl)'

# if you don't already have a PROMPT_COMMAND
export PROMPT_COMMAND='export PS1=$(gitprompt.pl)'
```

(The above assumes that `gitprompt.pl` is in your `PATH`; if not, specify its path explicitly.)

You also need to define the template which will be filled in with your Git status information.  This template goes in the `PS0` environment variable:

```
# ugly!  start with a nice-looking one from further below!
export PS0='\u@\h %{[%b; %c%u%f] %}\$ '
```

This tells `gitprompt.pl` to return (for use in `PS1`) a regular `bash` prompt like `\u@\h $ ` normally, but, when in a Git repo (`%{ ... %}`), to also include the branchname (`%b`) and flags for when files are to be committed (`%c`), updated but not added for commit (`%u`), or untracked (`%f`), all wrapped in `[...]`.  There are many such flags and many ways to combine and configure them in a way that is useful to you and your workflow.  By default, the above flags just return their letter (`c`, `u`, `f`), but this is completely configurable.  For example:

```
user@host [master; ] $ touch new-file
user@host [master; f] $ echo "a" >> file1
user@host [master; uf] $ echo "b" >> file2; git add file2
user@host [master; cuf] $ git status
# On branch master
# Changes to be committed:
#       modified:   file2
#
# Changed but not updated:
#       modified:   file1
#
# Untracked files:
#       new-file
```

The `gitprompt.pl` script itself also takes extra arguments that control how it returns its output.  These are all passed as `name=value` arguments to the script itself, usually specified within the invocation in `PROMPT_COMMAND`.  For example, if you like counts for each type of flag and symbols instead of letters, you could do:

```
export PROMPT_COMMAND='export PS1=$(gitprompt.pl c=\+ u=\~ f=\* statuscount=1)'
```

Now, the above example turns into:

```
user@host [master; +1~1*1] $ 
```

Here's a more interesting example which also removes the semicolon when the repo is clean:

```
user@host [master; +1~1*1] $ git reset --hard; rm new-file
user@host [master; ] $ export PROMPT_COMMAND='export PS1=$(gitprompt.pl c=\+ u=\~ f=\* statuscount=1 keepempty=0)'
user@host [master; ] $ export PS0='\u@\h %{[%b%}%{; %c%u%f%}%{%g] %}\$ '
user@host [master] $ touch new-file
user@host [master; *1] $ 
```

## Template Format Codes
These can be placed in `PS0` or the option definitions (for options which take
strings to output).  In `PS0`, bash escapes should be preferred when available.

```
%b - current branch name
%i - current commit id
%c - to-be-committed flag
%u - touched-files flag
%f - untracked-files flag
%A - merge commits ahead flag
%B - merge commits behind flag
%F - can-fast-forward flag
%t - terrible tragedy flag
%g - is-git-repo flag
%e - ascii escape
%[ - literal '\[' to mark the start of nonprinting characters for bash
%] - literal '\]' to mark the end of nonprinting characters for bash
%% - literal '%'
%{ - begin conditionally printed block, only shown if a nonliteral expands within
%} - end conditionally printed block
```

## Command-line options:
These are specified as arguments to the call to `gitprompt.pl` in the form
`name=value`, such as `$(gitprompt.pl c=\+ u=\~ f=\* statuscount=1)`.

```
c           - string to use for %c; defaults to 'c'
u           - string to use for %u; defaults to 'u'
f           - string to use for %f; defaults to 'f'
A           - string to use for %A; defaults to 'A'
B           - string to use for %B; defaults to 'B'
F           - string to use for %F; defaults to 'F'
t           - string to use for %t after a timeout; defaults to '?'
l           - string to use for %t when the repo is locked; defaults to '?~'
n           - string to use for %t when no data could be collected, such as
              if run from within a .git directory; defaults to '??'
g           - string to use for %g; defaults to the empty string (see %{)
statuscount - boolean; whether to suffix %c/%u with counts ("c4u8")
keepempty   - boolean; whether to always keep conditionals which only
              contain empty %x codes (but %g is always kept); default 1
```

## Better examples
A full prompt with symbols for statuses:
```
export PS0='\[\e[0;31m\][\t]\[\e[1m\][\h]\[\e[0;1m\][\w]\[\e[30;1m\]%{[%b\[\e[0m\]%c%u%f%t\[\e[30;1m\]]%}%{[\[\e[0m\]%B%A%F\[\e[30;1m\]]%}\[\e[0m\]\u\$ '
export PROMPT_COMMAND=$PROMPT_COMMAND';export PS1=$(gitprompt.pl c=\+ u=\~ f=\* A=/ B=\\\\ F=\ \>\> statuscount=1)'
```

Change branchname color:
```
export PS0='%{[\[%f%c%u%t\]%b\[\e[0m\]]%}\[\e[0m\]\u\$ '
export PROMPT_COMMAND=$PROMPT_COMMAND';export PS1=$(gitprompt.pl c=%e[32m u=%e[31m f=%e[35m t=%e[30\;1m)'
```

Colored counts instead of flags:
```
export PS0='%{\[\e[0;36m\](\[\e[1;36m\]%b\[\e[0;36m\])[%c%u%f%t\[\e[0;36m\]]%}\[\e[0m\]$ '
export PROMPT_COMMAND=$PROMPT_COMMAND';export PS1=$(gitprompt.pl statuscount=1 u=%[%e[31m%] c=%[%e[32m%] f=%[%e[1\;30m%])'
```

A simple style that used to be popular at Synacor:
```
export PS0='[\t]\[\e[36m\]%{(%b)\[\e[0;1m\][%c%u%f%t]%}\[\e[0m\]\u\$ '
export PROMPT_COMMAND=$PROMPT_COMMAND';export PS1=$(gitprompt.pl statuscount=1)'
```

## Notes
If your .bashrc doesn't already define a $PROMPT_COMMAND (this is common
in /etc/bashrc, which is often sourced by default), use this
PROMPT_COMMAND line instead:
```
export PROMPT_COMMAND='export PS1=$(gitprompt.pl ...)'
```

A good rule of thumb is to use real bash escapes (backslash flavor) inside
the definition for `PS0` (where escaping is normal) and `gitprompt.pl` escapes
(percent flavor) inside the arguments to `gitprompt.pl` (where escaping is
troublesome).

To prevent your prompt from getting garbled, wrap all nonprinting sequences
(like color codes) in `\[...\]` or `%[...%]`.  This tells Bash not to count
those characters when determining the length of your prompt and prevents it
from becoming confused.

For...  (assuming `%c` is whatever flags you care about)
- brackets no matter what, use `[%c]`
- brackets only in a git repo, regardless of status, use `%{[%c%g]%}`
- brackets only when a flag is set, use `%{[%c]%}`
