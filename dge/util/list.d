/++
Utilities for linked-list node trees
+/
module gui.util.list;

mixin template commonNode(Parent, Child) {
	//To do: make sure that this always instantiated using the *child's* "this" pointer, not the parent's?
	//Will the pointer even be used?
	class ParentAlreadyExistsError: Error {
		this() {
			super(Child.stringof ~ " already has a parent");
		}
	}
}

mixin template childNode(Parent, bool useCallback = false) {
	void addAfter(typeof(this) c) {
		if(_parent) {
			throw new ParentAlreadyExistsError;
		}
		if(!c._parent) {
			throw new Error(Parent.stringof ~ " has no parent; impossible to insert " ~
				typeof(this).stringof ~ " after it");
		}
		_parent = c._parent;
		if(_parent.lastChild is c) {
			_parent._lastChild = this;
		}
		_prevSibling = c;
		_nextSibling = c._nextSibling;
		c._nextSibling = this;
		if(_nextSibling) {
            _nextSibling._prevSibling = this;
		}
        static if(useCallback) {
            //To do: adjust order?
            onAdd();
			parent.onAddChild(this);
		}
	}

	void remove() {
		if(!_parent) {
			throw new Error(Parent.stringof ~ " has no parent from which to remove it.");
		}
		static if(useCallback) {
			onRemove();
			_parent.onRemoveChild(this);
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
		_parent = null;
		_prevSibling = null;
		_nextSibling = null;
	}

	@property Parent parent() {
		return _parent;
	}

	@property typeof(this) nextSibling() {
        return _nextSibling;
	}

	@property typeof(this) prevSibling() {
        return _prevSibling;
	}

	private:
	Parent _parent;
	typeof(this) _prevSibling, _nextSibling;
}

/++
Provides methods for a parent node

The parameter useCallback determines if the user-defined onAdd(), onRemove(), onAddChild(Child),
and onRemoveChild(Child) functions will be called.
+/
mixin template parentNode(Child, bool useCallback = false) {
	public:
	void add(Child child) {
        //To do: prevent cyclic parenting?
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

		static if(useCallback) {
            //To do: adjust order?
            child.onAdd();
			onAddChild(child);
		}
	}

	@property Child firstChild() {
		return _firstChild;
	}

	@property Child lastChild() {
		return _lastChild;
	}

	@property ChildRange children() {
        return ChildRange(firstChild);
    }

	protected:
	struct ChildRange {
        this(Child first) {
            _front = first;
		}

		@property Child front() {
            return _front;
		}

		/+
		To do:

		Throw error on empty?
		+/
		Child popFront() {
			auto oldFront = _front;
            _front = _front.nextSibling;
			return oldFront;
		}

		@property bool empty() {return _front is null;}

		@property ChildRange save() {return this;}

		private:
		Child _front;
    }

	private:
	Child _firstChild, _lastChild;
}
