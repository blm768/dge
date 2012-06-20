/++
Utilities for linked-list node trees
+/
module dge.util.list;

mixin template commonNode(Parent, Child) {
	//To do: make sure that this always instantiated using the *child's* "this" pointer, not the parent's?
	//Will the pointer even be used?
	class ParentAlreadyExistsError: Error {
		this() {
			super(Child.stringof ~ " already has a parent");
		}
	}
}

mixin template childNode(Parent) {
	void addAfter(Child c) {
		if(_parent) {
			throw new ParentAlreadyExistsError;
		}
		if(!c._parent) {
			throw new Error(Parent.stringof ~ " has no parent; impossible to insert " ~ Child.stringof ~ " after it");
		}
		_parent = c._parent;
		if(_parent.lastChild is c) {
			_parent.lastChild = this;
		}
		_prevSibling = c;
		_nextSibling = c._nextSibling;
		c._nextSibling = this;
		
	}
	
	void remove() {
		if(!parent) {
			throw new Error(Parent.stringof ~ " has no parent from which to remove it");
		}
		//Is there a previous node?
		if(_prevSibling) {
			_prevSibling._nextSibling = _nextSibling;
		} else {
			_parent._firstChild = _nextSibling;
		}
		//Is there a next node?
		if(_nextSibling) {
			_nextSibling._prevSibling = _prevSibling;
		} else {
			_parent._lastChild = _prevSibling;
		}
		_parent = _prevSibling = _nextSibling = null;
	}
	
	private:
	Parent _parent;
	typeof(this) _prevSibling, _nextSibling;
	
}

/++
Provides methods for a parent node

The parameter useCallback determines if the user-defined onAddChild(Child) and onRemoveChild(Child) functions will be called.
+/
mixin template parentNode(Child, bool useCallback = false) {
	public:
	void add(Child child) {
		if(child._parent) {
			throw new ParentAlreadyExistsError;
		}
		child._parent = this;
		//Is there already a last child?
		if(_lastChild) {
			_lastChild._nextSibling = child;
			child._prevSibling = lastChild;
			_lastChild = child;
		} else {
			_firstChild = _lastChild = child;
		}
	}
	
	private:
	Child _firstChild, _lastChild;
}