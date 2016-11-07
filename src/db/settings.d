module db.settings;

import std.xml;
import std.file;
import std.conv;
import std.range;

import fuji.dbg;

struct Settings
{
	void Load()
	{
		try
		{
			string s = readText("settings.xml");

			// parse xml
			auto xml = new DocumentParser(s);

			xml.onEndTag["theme"]				= (in Element e) { theme				= e.text(); };

			xml.onEndTag["videoDriver"]			= (in Element e) { videoDriver			= to!int(e.text()); };
			xml.onEndTag["audioDriver"]			= (in Element e) { audioDriver			= to!int(e.text()); };

			xml.onEndTag["audioLatency"]		= (in Element e) { audioLatency			= to!long(e.text()); };
			xml.onEndTag["videoLatency"]		= (in Element e) { videoLatency			= to!long(e.text()); };
			xml.onEndTag["controllerLatency"]	= (in Element e) { controllerLatency	= to!long(e.text()); };
			xml.onEndTag["midiLatency"]			= (in Element e) { midiLatency			= to!long(e.text()); };
			xml.onEndTag["micLatency"]			= (in Element e) { micLatency			= to!long(e.text()); };

			xml.onStartTag["devices"] = (ElementParser xml)
			{
				xml.onStartTag["device"] = (ElementParser xml)
				{
					Device device;
					device.id = xml.tag.attr["id"];

					xml.onEndTag["latency"] = (in Element e) { device.latency = to!int(e.text()); };
					xml.parse();

					devices ~= device;
				};
				xml.parse();
			};
			xml.parse();
		}
		catch (Exception e)
		{
			MFDebug_Warn(2, "Couldn't load settings: " ~ e.msg);
		}
	}

	void Save()
	{
		auto doc = new Document(new Tag("settings"));

		doc ~= new Element("theme", theme);

		doc ~= new Element("videoDriver", to!string(videoDriver));
		doc ~= new Element("audioDriver", to!string(audioDriver));

		doc ~= new Element("audioLatency", to!string(audioLatency));
		doc ~= new Element("videoLatency", to!string(videoLatency));
		doc ~= new Element("controllerLatency", to!string(controllerLatency));
		doc ~= new Element("midiLatency", to!string(midiLatency));
		doc ~= new Element("micLatency", to!string(micLatency));

		auto devs = new Element("devices");
		foreach (ref device; devices)
		{
			auto dev = new Element("Device");

			dev.tag.attr["id"] = device.id;

			dev ~= new Element("latency", to!string(device.latency));

			devs ~= dev;
		}
		doc ~= devs;

		string xml = join(doc.pretty(3),"\n");
		write("settings.xml", xml);
	}

	string theme = "default";

	int videoDriver;
	int audioDriver;

	long audioLatency;
	long videoLatency;
	long controllerLatency;
	long midiLatency;
	long micLatency;

	struct Device
	{
		// device type
		// controller/midi/audio

		string id;
		long latency;
	}

	Device[] devices;
}
