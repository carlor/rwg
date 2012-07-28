// Written in the D programming language.

// rwg.main - CLI, word generation functions
// Part of RWG - Random Word Generator
// Copyright (C) 2012 Nathan M. Swan
// Distributed under the Boost Software License
// (See accompanying file ../../LICENSE)

module rwg.main;

import std.algorithm;
import std.file;
import std.getopt;
import std.process;
import std.random;
import std.stdio;
import std.utf;

import rwg.rules;

int main(string[] args) {
    return Options().main(args);
}

// I don't like global state, so it's all one ref struct.
struct Options {

    // a single exception-catcher
    int main(string[] args) {
        this.args = args;
        try {
            realMain();
            return 0;
        } catch (Exception e) { // TODO RwgException
            stderr.writeln(e.msg);
            return 1;
        }
        assert(0);
    }
    
    // determines which method
    void realMain() {
        if (args.length == 0) {
            throw new Exception("Whoa! Zero arguments? What OS is this?");
        } else
        // no args means it was launched from GUI
        if (args.length == 1) {
            interactive();
        } else {
            commandLine();
        }
    }
    
    void interactive() {
        // TODO interactive
        stderr.writeln(`Please use the command line.`);
        writeUsage(stderr);
        stdin.readln();
    }
    
    // reads instructions from cmd-line args
    void commandLine() {
        bool showHelp, showManual, ignore;
        getopt(args,
            "h|help", &showHelp,
            "n|count", &wordcount,
            "l", &ignore, // the secret option!
            "man", &showManual
        );
        
        if (showHelp) { // --help
            writeUsage();
        } else if (showManual) { // --man
            displayManual();
        } else if (args.length > 1) { // ...
            rulefile = args[1];
            executeRwg();
        } else {
            if (getcwd().endsWith(".lang")) {
                string altfile = getcwd()[0 .. $-5] ~ ".rwg";
                if (altfile.exists) {
                    rulefile = altfile;
                    executeRwg();
                } else {
                    throw new Exception(altfile ~ " not found.");
                }
            } else {
                throw new Exception("File not specified");
            }
        }
    }
    
    // shows the command line options
    void writeUsage(File f = stdout) {
        f.writeln(
`Usage: `, args[0], ` [-h] [-n <count>] [--man] <langfile>

  langfile      an .rwg file
  -h, --help    shows this help
  -n, --count   sets wordcount
  --man         displays manual
`);
    }
    
    // displays the manual
    void displayManual() {
        enum ManualUrl = "http://github.com/carlor/rwg/";
        browse(ManualUrl);
    }
    
    // once all the input is received, it's go time
    void executeRwg() {
        readRules();
        generateWords();
    }
    
    void readRules() {
        rules.read(this);
    }
    
    void generateWords() {
        WordGen().generateWords(this);
    }
    
    // -- command line specs --
    string[] args;          // command line arguments
    string rulefile;        // filename specified
    uint wordcount = 100;   // number of words to generate
    
    // -- wordgen state --
    Rules rules;
    string[] words;
}

struct WordGen {
    void generateWords(ref Options opts) {
        foreach(i; 0 .. opts.wordcount) {
            writeln(generateWord(opts.rules));
        }
        //writeln(disallows(opts.rules, "ii"d));
    }
    
    string generateWord(ref Rules rules) {
        dstring attempt;
        do {
            attempt = tryWord(rules);
            //writeln("attempting ", toUTF8(attempt));
        } while (disallows(rules, attempt));
        //writeln("accepted...");
        
        return toUTF8(attempt);
    }
    
    dstring tryWord(ref Rules rules) {
        return generate(rules, rules.ruleToGenerate);
    }
    
    dstring generate(ref Rules rules, Rule rule) {
        //writeln("generating ", rule);
        if (rule.peek!Constant()) {
            auto r = rule.get!Constant();
            
            auto newRule = r in rules.definedRules;
            if (newRule) {
                return generate(rules, *newRule);
            } else {
                return r;
            }
        } else if (rule.peek!Sequence()) {
            dstring r;
            foreach(rl; rule.get!Sequence()) {
                r ~= generate(rules, rl);
            }
            return r;
        } else {
            assert(rule.peek!Choice());
            return generate(rules, rule.get!Choice()
                    .getAt(uniform!"()"(0.0f, 1.0f)));
        }
    }
    
    bool disallows(ref Rules rules, dstring attempt) {
        bool allows(bool b, dstring forbiddenSequence) {
            return b || attempt.canFind(forbiddenSequence);
        }
        return reduce!allows(false, rules.seqsToDisallow);
    }
}


