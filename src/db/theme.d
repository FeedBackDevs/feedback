module db.theme;

import db.game;
import db.ui.ui;
import db.ui.widget;
import db.ui.layoutdescriptor;

import fuji.dbg;
import fuji.filesystem;
import fuji.fs.native;
import fuji.fs.zip;

import std.algorithm;
import std.string;

class Theme
{
	static void initFilesystem()
	{
		scanForThemes();
	}

	static string themePath(string filename)
	{
		string fn = "theme:" ~ filename;
		if (MFFileSystem_Exists(fn))
			return MFFileSystem_ResolveSystemPath(fn).idup;
		return MFFileSystem_ResolveSystemPath("system:themes/default/" ~ filename).idup;
	}

	static Widget loadUi(string filename)
	{
		LayoutDescriptor desc = new LayoutDescriptor(filename);
		if (!desc)
		{
			MFDebug_Warn(2, "Couldn't load " ~ filename);
			return null;
		}

		Widget ui = desc.spawn();
		if (!ui)
		{
			MFDebug_Warn(2, "Couldn't spawn ui for " ~ filename);
			return null;
		}

		return ui;
	}

	static LayoutDescriptor loadUiDescriptor(string filename)
	{
		LayoutDescriptor desc = new LayoutDescriptor(filename);
		if (!desc)
		{
			MFDebug_Warn(2, "Couldn't load " ~ filename);
			return null;
		}
		return desc;
	}

	static Theme load(string theme)
	{
		import db.lua : doFile;

		if (theme !in themes)
		{
			MFDebug_Warn(2, "Theme not present: " ~ theme);
			return null;
		}

		if (themes[theme].theme)
			return themes[theme].theme;

		mountTheme(theme);

		Theme t = new Theme;

		themes[theme].theme = t;

		doFile("theme:theme.lua");

		return t;
	}

	//-------------------------------------------
	Widget ui;

private:
	static void scanForThemes()
	{
		foreach (entry; dirEntries("system:themes/*", SpanMode.shallow))
		{
			string name = entry.filename;
			if (name.endsWith(".zip"))
			{
				name = name[0..$-4];
			}
			else if (entry.attributes & (MFFileAttributes.Directory|MFFileAttributes.SymLink))
			{
				if (!MFFileSystem_Exists(entry.filepath ~ "/theme.lua"))
					continue;
			}
			else
				continue;

			if (name in themes)
			{
				MFDebug_Warn(2, "Theme already present: " ~ name);
				continue;
			}

			themes[name] = LocalTheme(name, entry.filepath);
		}
	}

	static void mountTheme(string theme)
	{
		LocalTheme* t = &themes[theme];

		if (t.isZip)
		{
			MFFile* pFile = fuji.filesystem.MFFileSystem_Open(t.path);
			if (!pFile)
			{
				MFDebug_Warn(2, "Couldn't open theme: " ~ t.path);
				return;
			}

			MFFileSystemHandle hZip = MFFileSystem_GetInternalFileSystemHandle(MFFileSystemHandles.ZipFileSystem);

			MFMountDataZipFile mountData;
			mountData.priority = MFMountPriority.AboveNormal;
			mountData.flags = MFMountFlags.Recursive;
			mountData.pMountpoint = "theme";
			mountData.pZipArchive = pFile;

			MFFileSystem_Dismount("theme");
			MFFileSystem_Mount(hZip, mountData);
		}
		else
		{
			MFFileSystemHandle hNative = MFFileSystem_GetInternalFileSystemHandle(MFFileSystemHandles.NativeFileSystem);

			MFMountDataNative mountData;
			mountData.priority = MFMountPriority.AboveNormal;
			mountData.flags = MFMountFlags.Recursive;
			mountData.pMountpoint = "theme";
			mountData.pPath = MFFile_SystemPath(t.path[7..$].toStringz);

			MFFileSystem_Dismount("theme");
			MFFileSystem_Mount(hNative, mountData);
		}
	}

	//-------------------------------------------
	struct LocalTheme
	{
		string name;
		string path;

		Theme theme;

		@property bool isZip() { return path.endsWith(".zip"); }
	}

	__gshared LocalTheme[string] themes;
}
