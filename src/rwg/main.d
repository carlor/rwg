// Written in the D programming language.

// rwg.main - CLI, word generation functions
// Part of RWG - Random Word Generator
// Copyright (C) 2012 Nathan M. Swan
// Distributed under the Boost Software License
// (See accompanying file ../../LICENSE)

module rwg.main;

import std.algorithm;
import std.conv;
import std.file;
import std.getopt;
import std.process;
import std.random;
import std.stdio;
import std.string;
import std.utf;

import rwg.compiler;
import rwg.rules;

// god ol' main
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
        } catch (Exception e) {
            stderr.writeln(e.msg);
            return 1;
        }
        assert(0);
    }
    
    // determines which method
    void realMain() {
        if (args.length == 0) {
            throw new Exception("Whoa! Zero arguments? What OS is this?");
        }
        
        // no args means it was launched from GUI
        if (args.length == 1) {
            interactive();
        } else {
            commandLine();
        }
    }
    
    void interactive() {
        writeln();
        write(`Welcome to rwg - the random word generator
Copyright (C) 2012 Nathan M. Swan

To start, drag rulefile here: `);
        rulefile = stdin.readln().idup.strip();
        write(`How many words do you want? `);
        try {
            wordcount = stdin.readln().idup.strip().to!int();
        } catch (ConvException ce) { wordcount = 100; }
        writeln();
        writeln("Okay, here goes...");
        writeln();
        executeRwg();
        writeln();
    }
    
    // reads instructions from cmd-line args
    void commandLine() {
        bool showHelp, showManual, ignore;
        getopt(args,
            "h|help", &showHelp,
            "n|count", &wordcount,
            "s|seed", &seed,
            "compile", &compile,
            "compile-out", &compileOut,
            "compile-only", &compileOnly,
            "l", &ignore, // the secret option!
            "man", &showManual
        );
        
        if (showHelp) { // --help
            writeUsage();
        } else if (showManual) { // --man
            displayManual();
        } else if (args.length > 1) { // normal
            rulefile = args[1];
            if (compile || compileOut !is null || compileOnly) {
                Rules().read(this);
                Compiler().compile(this);
            } else {
                executeRwg();
            }
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
`rwg 0.2
Copyright (C) 2012 Nathan M. Swan

Usage: `, args[0], ` [-h] [-n <count>] [--man] <langfile>

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
        rules.read(this);
        WordGen().generateWords(this);
    }
    
    // -- command line specs --
    string[] args;          // command line arguments
    string rulefile;        // filename specified
    uint wordcount = 100;   // number of words to generate
    uint seed = uint.max;
    
    // -- compilation options --
    bool compile = false;
    string compileOut = null;
    bool compileOnly = false;
    
    // -- wordgen state --
    Rules rules;
    string[] words;
}

// does the actual randomness
struct WordGen {

    // init seed, generateWord for num specified
    void generateWords(ref Options opts) {
        rg = Random(opts.seed == uint.max ? unpredictableSeed : opts.seed);
        foreach(i; 0 .. opts.wordcount) {
            writeln(generateWord(opts.rules));
        }
    }
    
    // keep trying until attempt is NOT disallowed
    string generateWord(ref Rules rules) {
        dstring attempt;
        do {
            attempt = tryWord(rules);
        } while (disallows(rules, attempt));
        
        return toUTF8(attempt);
    }
    
    // start at the top (ruleToGenerate)
    dstring tryWord(ref Rules rules) {
        return generate(rules, rules.ruleToGenerate);
    }
    
    // create random instance of the rule
    dstring generate(ref Rules rules, Rule rule) {
        if (rule.peek!Constant()) {
            auto r = rule.get!Constant();
            
            // a constant is either a DefinedRule or a phoneme.
            auto newRule = r in rules.definedRules;
            if (newRule) {
                return generate(rules, *newRule);
            } else {
                return r; // a random constant is a constant
            }
        } else if (rule.peek!Sequence()) {
            // generates each rule in the Sequence
            dstring r;
            foreach(rl; rule.get!Sequence()) {
                r ~= generate(rules, rl);
            }
            return r;
        } else {
            assert(rule.peek!Choice());
            // 1. generate random float 
            // 2. use getAt to get certain option 
            // 3. generate that option
            return generate(rules, rule.get!Choice()
                    .getAt(uniform!"()"(0.0f, 1.0f, rg)));
        }
    }
    
    bool disallows(ref Rules rules, dstring attempt) {
        // finding `forbiddenSequence` will make it true
        bool allows(bool b, dstring forbiddenSequence) {
            return b || attempt.canFind(forbiddenSequence);
        }
        return reduce!allows(false, rules.seqsToDisallow);
    }
    
    Random rg;
}


