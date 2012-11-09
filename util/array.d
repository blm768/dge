/++
Utilities for arrays
+/

module dge.util.array;

import std.algorithm;
import std.conv;
import std.range;

/++
A simple set.

By default, state is shared after copying; use Set.dup to create an independent set.
+/
struct Set(T) {
	public:

	this(T[] items) {
		//use add() to prevent duplicate entries
		foreach(T item; items) {
			add(item);
		}
	}

	//Syntactic sugar for this(T[] items)
	this(T[] items ...) {
		this(items);
	}

	void add(T item) {
		items[item] = [];
	}

	void add(Set!T other) {
		foreach(T i, ubyte[0] b; other.items) {
			add(i);
		}
	}

	void remove(Set!T other) {
		foreach(T i, ubyte[0] b; other.items) {
			remove(i);
		}
	}

	void remove(T item) {
		items.remove(item);
	}

	bool contains(T item) {
		return cast(bool)(item in items);
	}

	@property Set dup() {
		Set result;
		result.items = items.dup;
		return result;
	}

	@property size_t length() {
		return items.length;
	}

	int opApply(int delegate(ref T) dg) {
		int result = 0;

		foreach(T item, ubyte[0] b; items) {
			result = dg(item);
			if (result)
				break;
		}
		return result;
	}

	@property string toString() {
		string s = "Set(";
		foreach(item, dummy; items) {
			s ~= item.to!string;
			s ~= ", ";
		}
		s = s[0 .. $ - 2];
		s ~= ")";
		return s;
	}

	private:
	ubyte[0][T] items;
}


