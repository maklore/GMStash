//Text in red can be used as keys in item structs.
#macro GMSTASH_CONSUMABLE	"is_consumable" //Boolean
#macro GMSTASH_AMOUNT		"amount"		//Only required if consumable
#macro GMSTASH_AMOUNT_MAX	"amount_max"	//Only required if consumable

/**
 * A "simple" stash manager. 
 * Access the method's using the dot notation.
 * Example: GMStash.create("equipments", 11)
 * @returns {struct.GMStash}
 */
function GMStash() {
		
	static __stash = {};
	
	static __held_index = -1;
	
	static __held_item = undefined;
	
	static __active_stash = undefined;
	
	/**
	 * Create a named stash with set size
	 * @param {string} _name Name
	 * @param {real} _size Size
	 */
	static create = function(_name, _size) {
		if struct_exists(__stash, _name) { exit; }
		__stash[$ _name] = array_create(_size, undefined);
		__active_stash ??= _name;
	}
	
	/**
	 * Set the active stash
	 * @param {string} _name Name
	 */
	static active = function(_name) {
		__active_stash = _name;
	}
	
	/**
	 * Find if item exists, returns index, or undefined if not found
	 * @param {struct} _item Item struct
	 */
	static find = function(_item) {
		
		static __inventory_length = array_length(__stash[$ __active_stash]);
		
		var _name = _item.name;
		
		for (var i = 0; i < __inventory_length; ++i) {
			var _slot_check = __stash[$ __active_stash][i];
			if !is_undefined(_slot_check) and _slot_check.name == _name {
				
				if !struct_exists(_item, GMSTASH_CONSUMABLE) or !_item[$ GMSTASH_CONSUMABLE] {
					return i;	
				} else if _slot_check[$ GMSTASH_AMOUNT] < _slot_check[$ GMSTASH_AMOUNT_MAX] {
					return i;
				}
			}
		}
		
		return undefined;
	}
	
	/**
	 * Find empty slot, returns index, or undefined if not found
	 */
	static empty = function() {
		
		static __inventory_length = array_length(__stash[$ __active_stash]);
		
		for (var i = 0; i < __inventory_length; ++i) {
			var _slot_check = is_undefined(__stash[$ __active_stash][i]);
			if _slot_check {
				return i;	
			}
		}
		return undefined;
	}
	
	/**
	 * Returns item at set index from the active stash
	 * @param {real} _index Active stash slot index
	 */
	static get = function(_index) {
		return __stash[$ __active_stash][_index];
	}
	
	/**
	 * Get name stash
	 * @param {string} _name Name
	 */
	static get_stash = function(_name) {
		return __stash[$ _name];
	}
	
	/**
	 * Removes item at set index from the active stash
	 * @param {real} _index Active stash slot index
	 */
	static remove = function(_index) {
		array_set(__stash[$ __active_stash], _index, undefined);
	}
	
	/**
	 * Increases the items amount at set index in the active stash. Automatically adds item if more than items max amount
	 * @param {real} _index Active stash slot index
	 * @param {real} _amount Amount
	 */
	static increase = function(_index, _amount) {
		var _slot = array_get(__stash[$ __active_stash], _index);
		var _new_amount = _slot[$ GMSTASH_AMOUNT] + _amount;
		
		if _new_amount <= _slot[$ GMSTASH_AMOUNT_MAX] {
			_slot[$ GMSTASH_AMOUNT] = _new_amount;
			exit;
		}
		
		if _new_amount > _slot[$ GMSTASH_AMOUNT_MAX] {
			
			var _remaining_amount = _new_amount - _slot[$ GMSTASH_AMOUNT_MAX];
			_slot[$ GMSTASH_AMOUNT] = _slot[$ GMSTASH_AMOUNT_MAX];
			
			var _item_remainder = variable_clone(_slot);
			_item_remainder[$ GMSTASH_AMOUNT] = _remaining_amount;
			add(_item_remainder);
			exit;
		}
	}
	
	/**
	 * Decreases the items amount at set index in the active stash. Automatically removes item if less than zero
	 * @param {real} _index Active stash slot index
	 * @param {real} _amount Amount
	 */
	static decrease = function(_index, _amount) {
		
		var _slot = __stash[$ __active_stash][_index];
		
		if _slot.is_consumable {
			_slot[$ GMSTASH_AMOUNT] -= _amount;
		}
		
		if _slot[$ GMSTASH_AMOUNT] <= 0 {
			var _to_decrease = abs(_slot[$ GMSTASH_AMOUNT]);
			remove(_index);
			if _to_decrease > 0 {
				__decrease_restart(find(_slot), _to_decrease);
			}
		}
		
	}
	
	/**
	 * Adds item to active stash. Automatically finds, increases, and re-adds item consumables if more than max amount
	 * @param {struct} _item Item struct
	 */
	static add = function(_item) {
		
		var _slot = find(_item);
		if !is_undefined(_slot) and struct_exists(_slot, GMSTASH_CONSUMABLE) { 
			increase(_slot, _item[$ GMSTASH_AMOUNT]);
			return true;
		}
		
		_slot = empty();
		if is_undefined(_slot) { 
			return _item; 
		}
		
		if struct_exists(_slot, GMSTASH_CONSUMABLE) and _item[$ GMSTASH_AMOUNT] > _item[$ GMSTASH_AMOUNT_MAX] {
			
			var _remaining_amount = _item[$ GMSTASH_AMOUNT] - _item[$ GMSTASH_AMOUNT_MAX];
			_item[$ GMSTASH_AMOUNT] = _item[$ GMSTASH_AMOUNT_MAX];
			array_set(__stash[$ __active_stash], _slot, _item);
			
			var _item_remainder = variable_clone(_item);
			_item_remainder[$ GMSTASH_AMOUNT] = _remaining_amount;
			__add_restart(_item_remainder);
			return true;
		}

		array_set(__stash[$ __active_stash], _slot, _item);
		
		return true;
	}
		
	/**
	 * Temporarily captures item from the index slot of the active stash
	 * @param {real} _index Active stash slot index
	 */
	static hold = function(_index) {
		if __held_index != -1 { 
			return __held_index;
		}
		
		__held_index = _index;
		__held_item = __stash[$ __active_stash][__held_index];
		if is_undefined(__held_item) {
			__held_index = -1;
			__held_item = {};
		}
		return __held_index;
	}
	
	/**
	 * Releases temporarily captured item to set index of the active stash
	 * @param {real} _index Active stash slot index
	 */
	static release = function(_index, _target_stash = __active_stash) {
		if is_undefined(__held_item) { exit; }
		__swap(_index, _target_stash);
		__held_index = -1;
		__held_item = undefined;
	}
	
	/// @ignore
	static __add_restart = function(_item) {
		add(_item);
	}
	
	/// @ignore
	static __decrease_restart = function(_index, _amount) {
		decrease(_index, _amount);	
	}
	
	/// @ignore
	static __swap = function(_index, _target_stash) {
		__stash[$ __active_stash][__held_index] = __stash[$ _target_stash][_index];
		__stash[$ _target_stash][_index] = __held_item;
	}
	
	return static_get(GMStash);
}

GMStash();
