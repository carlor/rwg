// Written in the D programming language.

// rwg.rules - utilities for reading word files
// Part of RWG - Random Word Generator
// Copyright (C) 2012 Nathan M. Swan
// Distributed under the Boost Software License
// (See accompanying file ../../LICENSE)
module rwg.rules;

import std.array;
import std.algorithm;
import std.conv;
import std.file;
import std.range;
import std.string;
import std.uni;
import std.utf;
import std.variant;

import std.stdio; // TODO delete

import rwg.main;

// all the state of a rule file
struct Rules {
    // gets lines from specified file
    void read(in Options options) {
        // TODO stdio buffer?
        foreach(line; readText!string(options.rulefile).splitLines()) {
            interpretLine(toUTF32(line));
        }
        if (!ruleToGenerate.hasValue()) {
            throw new Exception("Rule to generate not specified!");
        }
        //writeln(ruleToGenerate, " ", seqsToDisallow);
    }
    
    // for each line in file:
    void interpretLine(dstring line) {
        /+
        for(auto tk = Tokenizer(line); !tk.empty; tk.popFront()) {
            write(tk.front, " ");
        }
        writeln(); +/
        tokens = Tokenizer(line);
        if (!tokens.empty) { // not comment or blank line
            switch (tokens.front) {
                case "generate":
                    generateDirective();
                    break;
                case "disallow":
                    disallowDirective();
                    break;
                default:
                    ruleDef();
            }
        }
    }
    
    // generate RuleName
    void generateDirective() {
        assert(tokens.front == "generate");
        tokens.popFront();
        
        ruleToGenerate = ruleExpr();
    }
    
    // disallow rule1, rule2, rule3
    void disallowDirective() {
        assert(tokens.front == "disallow");
        tokens.popFront();
        
        while(!tokens.empty) {
            if (tokens.front != ",") {
                foreach(c; tokens.front) {
                    // TODO get rid of this limitation
                    senforce(isAlpha(c), "you can only disallow constants");
                }
                seqsToDisallow ~= tokens.front;
            }
            tokens.popFront();
        }
    }
    
    // RuleName = <rule-expr>
    void ruleDef() {
        // RuleName
        auto key = tokens.front;
        tokens.popFront();
        
        // =
        senforce(!tokens.empty && tokens.front == "=",
                    "rule definitions must have =");
        tokens.popFront();
        
        // <rule-expr>
        definedRules[key] = ruleExpr();
    }
    
    // choice expression or sequence/constant
    Rule ruleExpr() {
        senforce(!tokens.empty, "rule expected");
        
        // Read a sequence
        Rule[] r;
        while(!tokens.empty && ![","d, "]"d].canFind(tokens.front)) {
            if (tokens.front == "[") {
                r ~= Rule(choiceExpr()); // choice
            } else {
                r ~= Rule(tokens.front); // constant
                tokens.popFront();
            }
        }
        
        // If sequence is one, it isn't a sequence
        if (r.length == 1) return Rule(r[0]);
        // ...it is
        else return Rule(r);
    }
    
    // [option1, option2, option3]
    Choice choiceExpr() {
        assert(tokens.front == "[");
        
        Choice r;
        float percent = 0.0;
        bool doneWithPercentages = false;
        
        while(!tokens.empty) {
            if (tokens.front == "," || tokens.front == "[") {
                tokens.popFront();
                if (tokens.front.back == '%') {
                    senforce(!doneWithPercentages, "Percents must be first.");
                    percent += to!float(tokens.front[0 .. $-1]) / 100.0;
                    senforce(percent <= 1.0, "Percent overflow");
                    tokens.popFront();
                    r.percentages ~= percent; 
                    r.options ~= ruleExpr();
                } else {
                    doneWithPercentages = true;
                    r.options ~= ruleExpr();
                }
            } else {
                senforce(tokens.front == "]", "Bracket or comma expected");
                tokens.popFront();
                break;            
            }
        }
        
        auto nLastPercents = r.options.length - r.percentages.length;
        float lastPercent = (1.0 - percent) / nLastPercents;
        foreach(i; 0 .. nLastPercents) {
            percent += lastPercent;
            r.percentages ~= percent;
        }
        
        //writeln(r);
        
        return r;
    }
    
    // -- file-reading state --
    Tokenizer tokens;
    
    // -- rule state --
    Rule ruleToGenerate;
    dstring[] seqsToDisallow;
    Rule[dstring] definedRules;
}

/+ Takes a string and turns it into tokens:
    RuleName
    i           phone literal
    50%         percentage
    [ ] , =     operator
    
   ignoring whitespace, comments
 +/
struct Tokenizer {
    this(dstring _str) {
        str = _str;
        popFront();
    }
    
    bool empty;
    dstring front;
    
    void popFront() {
        assert(!empty);
        stripWhitespace();
        if (str.empty || str.front == '#') {
            empty = true;
        } else {
            front = "";
            deduceToken();
        }
    }
    
    void deduceToken() {
        if ("0123456789".canFind(str.front)) { // number
            while(!str.empty) {
                front ~= str.front;
                str.popFront();
                if (front.back == '%') break;
            }
        } else if ("[],=".canFind(str.front)) { // operator
            front = [str.front];
            str.popFront();
        } else { // RuleName, directive, phone
            while(!str.empty && !"[],= \t\r\n".canFind(str.front)) {
                front ~= str.front;
                str.popFront();
            }
        }
    }
    
    void stripWhitespace() {
        str = stripLeft(str);
    }
    
    dstring str;
}

// gives a syntax error message
void senforce(bool cond, string errmsg="") {
    if (!cond) {
        string msg;
        if (errmsg.empty) {
            msg = "Syntax error";
        } else {
            msg = "Syntax error: "~errmsg;
        }
        throw new Exception(msg);
    }
}

/+ A rule is:
    - a Sequence of other rules
    - a Choice between rules
    - a Constant list of phones
 +/
alias Variant Rule;
alias Rule[] Sequence;
alias dstring Constant;

struct Choice {
    Rule getAt(float f) {
        assert(f != 0.0 && f != 1.0);
        //writeln("getAt among ", options);
        foreach(i, percentage; percentages) {
            //writefln("float: %s, i: %s, percentage: %s", f, i, percentage);
            if (percentage >= f) {
                return options[i];
            }
        }
        return options[$-1]; // rounding down makes none work
    }
    
    float[] percentages;
    Rule[] options;
}


unittest {
    auto c = Choice([0.7, 0.75, 1.0], [Rule("a"), Rule("b"), Rule("c")]);
    assert(c.getAt(0.5) == "a");
    assert(c.getAt(0.72) == "b");
    assert(c.getAt(0.9) == "c");
}


