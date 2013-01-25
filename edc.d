module dge.edc;

import std.conv;
import std.stdio;
import std.string;

template readEdc(string filename, alias string[] params = cast(string[])[]) {
	mixin("string readEdc(" ~ params.join(", ") ~ ") {
	" ~ EdcParser(import(filename)).codeText ~ "
	writeln(`" ~ filename ~ "`);
	}");
}

struct EdcParser {
	this(string text) {
		this.text = text;
		nextChunk = &getTextChunk;
	}
	
	@property string codeText() {
		string chunk;
		string codeText = "string text;";
		do {
			chunk = nextChunk();
			codeText ~= chunk;
		} while(text.length > 0);
		codeText ~= "return text;";
		return codeText;
	}
	
	private:
	string text;
	string delegate() nextChunk;
	
	string getTextChunk() {
		auto index = text.indexOf("<#");
		string chunk;
		if(index > -1) {
			chunk = text[0 .. index];
			if(index + 2 < text.length && text[index + 2] == '=') {
				text = text[index + 3 .. $];
				nextChunk = &getExpressionChunk;
			} else {
				text = text[index + 2 .. $];
				nextChunk = &getRawCodeChunk;
			}
		} else {
			chunk = text;
			text = [];
		}
		return "text ~= `" ~ chunk ~ "`;";
	}
	
	string skipLeadingNewline() {
		if(text.length > 0) {
			auto index = text.indexOf("\n");
			if(index > -1) {
				if(text[0 .. index].strip.length == 0) {
					text = text[index + 1 .. $];
				}
			}
		}
		nextChunk = &getTextChunk;
		return "";
	}
	
	string getCodeChunk() {
		string chunk;
		auto index = text.indexOf("#>");
		if(index > -1) {
			chunk = text[0 .. index];
			text = text[index + 2 .. $];
		} else {
			throw new Error("Unterminated code block");
		}
		return chunk;
	}
	
	string getRawCodeChunk() {
		string chunk = getCodeChunk();
		nextChunk = &skipLeadingNewline;
		return chunk;
	}
	
	//To do: make sure expression is non-empty?
	string getExpressionChunk() {
		string chunk = getCodeChunk();
		nextChunk = &getTextChunk;
		if(chunk.length > 0) {
			return "text ~= to!string(" ~ chunk ~ ");";
		} else {
			return "";
		}
	}
}