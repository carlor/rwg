// Written in the D programming language.

// rwg.compiler - compiles rulefiles into executables
// Part of RWG - Random Word Generator
// Copyright (C) 2012 Nathan M. Swan
// Distributed under the Boost Software License
// (See accompanying file ../../LICENSE)

module rwg.compiler;

import std.conv;
import std.exception;
import std.process;
import std.stdio;

import rwg.main;
import rwg.rules;

struct Compiler {
    void compile(ref Options opts) {
        readOpts(opts);
        createSource();
        runRdmd(opts.wordcount, opts.seed);
    }
    
    void readOpts(ref Options opts) {
        shouldRun = !opts.compileOnly;
        ofile = opts.compileOut;
        enforce(shouldRun || ofile !is null,
            "--compile-only requires the setting of --compile-out");
        ifile = opts.rulefile;
        rules = opts.rules;
    }
    
    void createSource() {
        srcName = std.path.stripExtension(ifile)~".d";
        src = File(srcName, "w");
        src.writeln(`// auto-generated by rwg
// DO NOT MODIFY as this will be overridden the next run

import std.algorithm, std.getopt, std.random, std.stdio;

void main(string[] args) {
    uint wc=100, sd=unpredictableSeed;
    getopt(args, "n|count", &wc, "s|seed", &sd);
    auto r=Random(sd);
    foreach(i; 0 .. wc) {
        string wrd;
        do {
            wrd = "";
            tryWord(r, wrd);
        } while (disallowed(wrd));
        writeln(wrd);
    }
}`);
        
        // assign rulenums to defined rules
        foreach(name, rule; rules.definedRules) {
            defRulesToNums[name] = rulenum++;
        }
        
        // undefined rules
        foreach(name, rule; rules.definedRules) {
            src.writefln("// generates %s", name);
            writeRule(rule, defRulesToNums[name]);
        }
        
        // disallow directive
        src.writeln(`bool disallowed(string wrd) {`);
        foreach(dr; rules.seqsToDisallow) {
            src.writefln(`if (wrd.canFind("%s")) { return true; }`, dr);
        }
        src.writeln(`return false;`);
        src.writeln(`}`);
        
        // generate directive
        auto orig = rulenum++;
        writeRule(rules.ruleToGenerate, orig);
        src.writefln(`alias rule%s tryWord;`, orig);
        
        src.close();
    }
    
    void writeRule(Rule rule, size_t rnum) {
        //writefln("prob #%s = %s", rnum, rule);
        src.writefln("void rule%s(ref Random r, ref string result) {", rnum);
        if (rule.peek!(Constant)) {
            auto cons = rule.get!(Constant)();
            if (cons in rules.definedRules) {
                src.writefln("rule%s(r, result);", defRulesToNums[cons]);
            } else {
                src.writefln("result ~= \"%s\";", cons); // TODO sanitize?
            }
            src.writeln("}");
        } else if (rule.peek!(Sequence)) {
            auto orig = rulenum;
            foreach(rl; rule.get!(Sequence)()) {
                src.writefln("rule%s(r, result);", rulenum++);
            }
            src.writeln("}");
            foreach(rl; rule.get!(Sequence)()) {
                writeRule(rl, orig++);
            }
        } else if (rule.peek!(Choice)) {
            src.writeln(`auto f = uniform!"()"(0.0, 1.0, r);`);
            auto orig = rulenum;
            auto choice = rule.get!(Choice);
            foreach(p; choice.percentages[0 .. $-1]) {
                src.writefln(`if (f < %s) { rule%s(r, result); return; }`,
                    p, rulenum++);
            }
            src.writefln(`rule%s(r, result);`, rulenum++);
            src.writeln(`}`);
            foreach(o; choice.options) {
                writeRule(o, orig++);
            }
        } else assert(0);
    }
    
    void runRdmd(uint wc, uint seed) {
        string[] args;
        args ~= "rdmd";
        if (!shouldRun) {
            args ~= "--build-only";
        }
        if (ofile !is null) {
            args ~= "-of"~ofile;
        }
        args ~= srcName;
        args ~= "-n"~to!string(wc);
        args ~= "-s"~to!string(seed);
        execvp("rdmd", ["rdmd", srcName]);
    }
    
    bool shouldRun;
    string ifile;
    string ofile;
    Rules rules;
    
    File src;
    string srcName;
    
    size_t rulenum = 0;
    size_t[dstring] defRulesToNums;
}


