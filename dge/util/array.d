/++
Utilities for arrays
+/

module dge.util.array;

import std.array;

/++
Removes the element at index from a dynamic array.

Meant to emulate the functionality of .remove(key) from associative arrays for standard dynamic arrays.
+/
ref T remove(T)(ref T array, size_t index) {
	array = array[0 .. index] ~ array[index + 1 .. $];
	return array;
}


/++
A simple mathematical set.

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
		items[item] = true;
	}
	
	void add(Set!T other) {
		foreach(T i, bool b; other.items) {
			add(i);
		}
	}
	
	void remove(Set!T other) {
		foreach(T i, bool b; other.items) {
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

		foreach(T item, bool b; items) {
			result = dg(item);
			if (result)
				break;
		}
		return result;
	}
  
	private:
	bool[T] items;
}

/++ Similar to Set, but keeps elements in order by using a linear array.

Lookup is performed with a hash table, but this table must be rebuilt after every insertion,
so avoid insertions when possible.+/
struct LinearOrderedSet(T) {
	
	void insertBefore(T pos, T item) {
		//Avoid duplicates.
		if(item in lookup)
			return;
		
		size_t index = lookup[pos];
		items.insertInPlace(lookup[pos], [item]);
		buildLookup(index);
	}
	
	void insertAfter(T pos, T item) {
		//Avoid duplicates.
		if(item in lookup)
			return;
		
		size_t index = lookup[pos] + 1;
		items.insertInPlace(lookup[pos], [item]);
		buildLookup(index);
	}
	
	void remove(T item) {
		size_t index = lookup[item];
		
		//Slide the elements over.
		T[] chunk = items[index + 1 .. $];
		items.length = index;
		items ~= chunk;
		
		lookup.remove(item);
		buildLookup(index);
	}
	
	private:
	void buildLookup(size_t start = 0) {
		foreach(size_t i, T item; items[start .. $]) {
			lookup[item] = i;
		}
	}
	
	T[] items;
	size_t[T] lookup;
}
