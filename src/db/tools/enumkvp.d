module db.tools.enumkvp;

import std.traits;
import std.range;
import std.string;

struct KeyValuePair(ValueType)
{
	string key;
	ValueType value;
}

template EnumKeyValuePair(Enum)
{
	template impl(size_t len, size_t offset, Items...)
	{
		static if(offset == len)
			alias impl = TypeTuple!();
		else
			alias impl = TypeTuple!(KeyValuePair!Enum(Items[offset], Items[len + offset]), impl!(len, offset + 1, Items));
	}

	alias Keys = TypeTuple!(__traits(allMembers, Enum));
	alias Values = EnumMembers!Enum;
	static assert(Keys.length == Values.length);

	alias EnumKeyValuePair = impl!(Keys.length, 0, TypeTuple!(Keys, Values));
}

immutable(KeyValuePair!Enum)[] getKeyValuePair(Enum)() nothrow
{
	static immutable(KeyValuePair!Enum[]) kvp = [ EnumKeyValuePair!Enum ];
	return kvp;
}

Enum getEnumValue(Enum)(const(char)[] value) if(is(Enum == enum))
{
	value = value.strip;
	if(!value.empty)
	{
		auto kvp = getKeyValuePair!Enum();
		foreach(i; kvp)
		{
			if(!icmp(i.key, value))
				return i.value;
		}
	}
	return cast(Enum)-1;
}

uint getBitfieldValue(Enum)(const(char)[] flags)
{
	uint value;
	foreach(token; flags.splitter('|').map!(a => a.strip).filter!(a => !a.empty))
	{
		Enum val = getEnumValue!Enum(token);
		if(val != cast(Enum)-1)
			value |= val;
	}
	return value;
}

string getEnumFromValue(Enum)(Enum value)
{
	auto kvp = getKeyValuePair!Enum();
	foreach(i; kvp)
	{
		if(value == i.value)
			return i.key;
	}
	return null;
}

string getBitfieldFromValue(Enum)(uint bits)
{
	string bitfield;
	foreach(i; 0..32)
	{
		uint bit = 1 << i;
		if(!(bits & bit))
			continue;

		string key = getEnumFromValue(cast(Enum)bit);
		if(key)
		{
			if(!bitfield)
				bitfield = key;
			else
				bitfield = bitfield ~ "|" ~ key;
		}
	}
	return bitfield;
}