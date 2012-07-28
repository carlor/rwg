rwg - the Random Word Generator
===============================
The Random Word Generator generates words from a rulefile.

Command Line Options
--------------------
Usage: `rwg [-h] [-l] [-n <count>] [--man] <rulefile>`

* The `-h` option shows a basic description of the command line arguments.
* The `-l` is a mystery option!
* The `-n` determines how many words will be generated; 100 is the default.
* The `--man` opens the RWG homepage in the browser.
* The required `<rulefile>` is the location of a rulefile in the file system.

Rulefile
--------
Rulefiles contain ASCII or UTF-8 plain text
Comments reside between the `#` character and a newline; these are ignored.

Any line can be:
* a blank line.
* a `generate` declaration.
* a `disallow` declaration.
* a rule definition.

All rulefiles must have a single `generate` declaration.
This must define what rule to generate:
    
    generate Word
    
Rulefiles may contain a `disallow` declaration.
The comma-separated character sequences are banned;
when `rwg` generates a word with a disallowed sequence, it retries.
    
    disallow yi, wu # if rwg generates e.g. "payi", it will try again
    

Most important are rule definitions, of the syntax:
    
    <RuleName> = <RuleExpr>
    
RuleNames should start with upper-case alphabetic characters, preferrably
within Ascii.

Rule Expressions
----------------
A rule expression can be:
    
    # A simple constant.
    Coda = n
    
    # A rule name.
    Nucleus = Vowel
    
    # A sequence of various rulexprs:
    Syllable = Onset Nucleus [20% n, ]
    
    # A random choice between rulexprs
    Vowel = [a, e, i, o, u]
    
    # Which may include a choice of nothing:
    Onset = [p, t, k, ]
    
    # Percentages may be given starting from the left:
    Onset = [80% Consonant, Stop Liquid]
    
    # This is invalid:
    Coda = [Consonant, 20% Stop Liquid]
    
For any questions, please contact the author whose gmail username is 
`nathanmswan`.
    
    
