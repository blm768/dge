/++
General utilities
+/
module dge.util;

//Not working. Don't use.
string readOnlyProperty(T)(string name) pure {
	return `
		public @property ` ~ T.stringof ~ " " ~ name ~ `() {
			return _` ~ name ~ `;
		}
		`;
}