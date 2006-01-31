using System;
using System.Collections.Generic;
using System.ComponentModel.Design;
using System.Windows.Forms;
using System.Diagnostics;
using System.Resources;
using System.Reflection;
using System.Runtime.InteropServices;
using OleInterop = Microsoft.VisualStudio.OLE.Interop;
using Microsoft.VisualStudio.Shell.Interop;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio;
using Microsoft.VisualStudio.EnterpriseTools.Shell;
using Microsoft.VisualStudio.TextManager.Interop;
using Microsoft.Win32;
using Neumont.Tools.ORM.FactEditor;

using SubStore = Microsoft.VisualStudio.Modeling.SubStore;

namespace Neumont.Tools.ORM.Shell
{
	#region Attributes
	/// <summary>
	/// Entry point for the ORMPackage package. An instance of this class is created by the VS
	/// shell whenever one of our services is required.
	/// </summary>
	[Guid("EFDDC549-1646-4451-8A51-E5A5E94D647C")]
	[CLSCompliant(false)]

	// "ORM Designer" and "General" correspond and must be in sync with ORMDesignerUI.rc
	[ProvideOptionPage(typeof(OptionsPage), "ORM Designer", "General", 105, 106, false)]
	[ProvideEditorFactory(typeof(ORMDesignerEditorFactory), 108, TrustLevel=__VSEDITORTRUSTLEVEL.ETL_AlwaysTrusted)]
	// The following ProvideEditorExtension attributes are for {General, Misc, Solution} Items, in that order
	[ProvideEditorExtension(typeof(ORMDesignerEditorFactory), ".orm", 0x32, NameResourceID=107, TemplateDir=@"C:\Program Files\Neumont\ORM Architect for Visual Studio\ORMProjectItems\", ProjectGuid="2150E333-8FDC-42A3-9474-1A3956D46DE8")]
	[ProvideEditorExtension(typeof(ORMDesignerEditorFactory), ".orm", 0x32, NameResourceID=107, TemplateDir=@"C:\Program Files\Neumont\ORM Architect for Visual Studio\ORMProjectItems\", ProjectGuid="A2FE74E1-B743-11d0-AE1A-00A0C90FFFC3")]
	[ProvideEditorExtension(typeof(ORMDesignerEditorFactory), ".orm", 0x32, NameResourceID=107, TemplateDir=@"C:\Program Files\Neumont\ORM Architect for Visual Studio\ORMProjectItems\", ProjectGuid="D1DCDB85-C5E8-11d2-BFCA-00C04F990235")]
	[ProvideEditorExtension(typeof(ORMDesignerEditorFactory), ".xml", 0x10)]
	[ProvideService(typeof(ORMDesignerFontsAndColors), ServiceName="OrmDesignerFontAndColorProvider")]
	[ProvideLanguageService(typeof(FactLanguageService), "ORM Fact Editor", 109, ShowCompletion=true, ShowSmartIndent=false, RequestStockColors=false, ShowHotURLs=false, DefaultToNonHotURLs=false, DefaultToInsertSpaces=false, ShowDropDownOptions=false, SingleCodeWindowOnly=true, EnableAdvancedMembersOption=false, SupportCopyPasteOfHTML=true)]
	[ProvideToolWindow(typeof(ORMDesignerPackage.FactEditorToolWindowShim), Style=VsDockStyle.Float, Transient=true, PositionX=200, PositionY=500, Width=800, Height=250, Orientation=ToolWindowOrientation.Right, Window=ToolWindowGuids.Outputwindow)]
	[ProvideToolWindow(typeof(ORMReferenceModeEditorToolWindow), Style=VsDockStyle.Float, Transient=true, PositionX=200, PositionY=100, Width=500, Height=350, Orientation=ToolWindowOrientation.Right, Window=ToolWindowGuids.Outputwindow)]
	[ProvideToolWindow(typeof(ORMReadingEditorToolWindow), Style=VsDockStyle.Tabbed, Transient=true, Orientation=ToolWindowOrientation.Right, Window=ToolWindowGuids.Outputwindow)]
	[ProvideToolWindow(typeof(ORMVerbalizationToolWindow), Style=VsDockStyle.Tabbed, Transient=true, Orientation=ToolWindowOrientation.Right, Window=ToolWindowGuids.Outputwindow)]
	[ProvideToolWindow(typeof(ORMBrowserToolWindow), Style=VsDockStyle.Tabbed, Transient=true, Orientation=ToolWindowOrientation.Right, Window=ToolWindowGuids.Outputwindow)]
	[ProvideToolWindowVisibility(typeof(ORMDesignerPackage.FactEditorToolWindowShim), ORMDesignerEditorFactory.GuidString)]
	[ProvideToolWindowVisibility(typeof(ORMReferenceModeEditorToolWindow), ORMDesignerEditorFactory.GuidString)]
	[ProvideToolWindowVisibility(typeof(ORMReadingEditorToolWindow), ORMDesignerEditorFactory.GuidString)]
	[ProvideToolWindowVisibility(typeof(ORMVerbalizationToolWindow), ORMDesignerEditorFactory.GuidString)]
	[ProvideToolWindowVisibility(typeof(ORMBrowserToolWindow), ORMDesignerEditorFactory.GuidString)]
	[ProvideMenuResource(1000, 1)]
	[ProvideToolboxItems(1, true)]
	[ProvideToolboxFormat("Microsoft.VisualStudio.Modeling.ElementGroupPrototype")]
	[DefaultRegistryRoot(@"SOFTWARE\Microsoft\VisualStudio\8.0Exp")]
	[PackageRegistration(UseManagedResourcesOnly=false, RegisterUsing=RegistrationMethod.CodeBase, SatellitePath=@"C:\Program Files\Neumont\ORM Architect for Visual Studio\bin\")]
	[InstalledProductRegistration(true, null, null, null, LanguageIndependentName="Neumont ORM Architect")]
	[ProvideLoadKey("Standard", "1.0", "Neumont ORM Architect for Visual Studio", "Neumont University", 150)]
	#endregion // Attributes
	public sealed class ORMDesignerPackage : ModelingPackage, IVsInstalledProduct
	{
		#region FactEditorToolWindow Shim
		// HACK: This exists only so that the ProvideToolWindowAttribute can pull the GUID off of it.
		[Guid(FactGuidList.FactEditorToolWindowGuidString)]
		private static class FactEditorToolWindowShim { }
		#endregion // FactEditorToolWindow Shim

		#region Constants
		private const string REGISTRYROOT_PACKAGE = @"Neumont\ORM Architect";
		private const string REGISTRYROOT_EXTENSIONS = REGISTRYROOT_PACKAGE + @"\Extensions";
		private const string REGISTRYVALUE_SETTINGSPATH = "SettingsPath";
		private const string REGISTRYVALUE_CONVERTERSDIR = "ConvertersDir";
		#endregion

		#region Member variables
		/// <summary>
		/// The commands supported by this package
		/// </summary>
		private object myCommandSet;
		private IVsWindowFrame myFactEditorToolWindow;
		private ORMDesignerFontsAndColors myFontAndColorService;
		private ORMDesignerSettings myDesignerSettings;
		private static ORMDesignerPackage mySingleton;
		#endregion
		#region Construction/destruction
		/// <summary>
		/// Class constructor.
		/// </summary>
		public ORMDesignerPackage()
		{
			Debug.Assert(mySingleton == null); // Should only be loaded once per IDE session
			mySingleton = this;
		}
		#endregion
		#region Properties
		/// <summary>
		/// Gets the singleton command set create for this package.
		/// </summary>
		public static object CommandSet
		{
			get
			{
				ORMDesignerPackage package = mySingleton;
				return (package != null) ? package.myCommandSet : null;
			}
		}
		/// <summary>
		/// Gets the singleton font and color service for this package
		/// </summary>
		public static ORMDesignerFontsAndColors FontAndColorService
		{
			get
			{
				ORMDesignerPackage package = mySingleton;
				return (package != null) ? package.myFontAndColorService : null;
			}
		}
		/// <summary>
		/// Get the designer settings for this package
		/// </summary>
		public static ORMDesignerSettings DesignerSettings
		{
			get
			{
				ORMDesignerPackage package = mySingleton;
				if (package != null)
				{
					ORMDesignerSettings retVal = package.myDesignerSettings;
					if (retVal == null)
					{
						RegistryKey applicationRegistryRoot = null;
						RegistryKey normaRegistryRoot = null;
						try
						{
							applicationRegistryRoot = package.ApplicationRegistryRoot;
							normaRegistryRoot = applicationRegistryRoot.OpenSubKey(REGISTRYROOT_PACKAGE, RegistryKeyPermissionCheck.ReadSubTree);
							string settingsPath = (string)normaRegistryRoot.GetValue(REGISTRYVALUE_SETTINGSPATH, String.Empty);
							string xmlConvertersDir = (string)normaRegistryRoot.GetValue(REGISTRYVALUE_CONVERTERSDIR, String.Empty);
							package.myDesignerSettings = new ORMDesignerSettings(package, settingsPath, xmlConvertersDir);
						}
						finally
						{
							if (applicationRegistryRoot != null)
							{
								applicationRegistryRoot.Close();
							}
							if (normaRegistryRoot != null)
							{
								normaRegistryRoot.Close();
							}
						}
						retVal = package.myDesignerSettings;
					}
					return retVal;
				}
				return null;
			}
		}
		/// <summary>
		/// For use by unit tests. Also used by ModelElementLocator.
		/// Private to discourage use outside of unit testing,
		/// may only be accessed through reflection.
		/// </summary>
		private static ORMDesignerPackage Singleton
		{
			get
			{
				return mySingleton;
			}
		}
		#endregion // Properties
		#region Base overrides
		/// <summary>
		/// This is called by the package base class when our package is loaded. When devenv is run
		/// with the "/setup" command line switch it is not able to do a lot of the normal things,
		/// such as creating output windows and tool windows. Under normal circumstances our package
		/// isn't loaded when run with this switch. However, our package will be loaded when items 
		/// are added to the toolbox, even when run with "/setup". To be safe we'll check for "setup"
		/// and we don't do anything interesting in MgdSetSite if we find it. 
		/// </summary>
		protected override void Initialize()
		{
			base.Initialize();

			// register the class designer editor factory
			RegisterModelingEditorFactory(new ORMDesignerEditorFactory(this));

			if (!SetupMode)
			{
				base.ToolboxInitialized += this.ToolboxHandler;
				base.ToolboxUpgraded += this.ToolboxHandler;

				IServiceContainer service = (IServiceContainer)this;
				myFontAndColorService = new ORMDesignerFontsAndColors(this);
				service.AddService(typeof(ORMDesignerFontsAndColors), myFontAndColorService, true);
				service.AddService(typeof(FactLanguageService), new FactLanguageService(this), true);
				
				// setup commands
				myCommandSet = ORMDesignerDocView.CreateCommandSet(this);

				// Create tool windows
				AddToolWindow(typeof(ORMBrowserToolWindow));
				AddToolWindow(typeof(ORMReadingEditorToolWindow));
				AddToolWindow(typeof(ORMReferenceModeEditorToolWindow));
				AddToolWindow(typeof(ORMVerbalizationToolWindow));
				EnsureFactEditorToolWindow();
				
				// Make sure our options are loaded from the registry
				GetDialogPage(typeof(OptionsPage));
				
				base.SetupDynamicToolbox();
			}

		}
		/// <summary>
		/// Handles the <see cref="Package.ToolboxInitialized"/> and <see cref="Package.ToolboxUpgraded"/> events.
		/// </summary>
		private void ToolboxHandler(object sender, EventArgs e)
		{
			base.SetupDynamicToolbox();
		}
		/// <summary>
		/// This is called by the package base class when our package gets unloaded.
		/// </summary>
		protected override void Dispose(bool disposing)
		{
			if (disposing)
			{
				IServiceContainer service = (IServiceContainer)this;
				service.RemoveService(typeof(ORMDesignerFontsAndColors), true);

				if (myFactEditorToolWindow != null)
				{
					myFactEditorToolWindow.CloseFrame(0);
				}

				service.RemoveService(typeof(FactLanguageService), true);
				// dispose of any private objects here
			}
			base.Dispose(disposing);
		}
		/// <summary>
		/// Specifies the name of the DTE object used to bootstrap unit testing.  Derived classes
		/// should specify a unique name.
		/// </summary>
		protected override string UnitTestObjectName
		{
			get
			{
				return "ORMDesignerTestDriver";
			}
		}
		#endregion // Base overrides
		#region FactEditorToolWindow Creation
		private IVsWindowFrame EnsureFactEditorToolWindow()
		{
			IVsWindowFrame frame = myFactEditorToolWindow;
			if (frame == null)
			{
				myFactEditorToolWindow = frame = AddFactEditorToolWindow();
			}
			return frame;
		}
		private IVsWindowFrame AddFactEditorToolWindow()
		{
			ILocalRegistry3 locReg = (ILocalRegistry3)this.GetService(typeof(ILocalRegistry));
			IntPtr pBuf = IntPtr.Zero;
			Guid iid = typeof(IVsTextLines).GUID;
			ErrorHandler.ThrowOnFailure(locReg.CreateInstance(
				typeof(VsTextBufferClass).GUID,
				null,
				ref iid,
				(uint)OleInterop.CLSCTX.CLSCTX_INPROC_SERVER,
				out pBuf));

			IVsTextLines lines = null;
			OleInterop.IObjectWithSite objectWithSite = null;
			try
			{
				// Get an object to tie to the IDE
				lines = (IVsTextLines)Marshal.GetObjectForIUnknown(pBuf);
				objectWithSite = lines as OleInterop.IObjectWithSite;
				objectWithSite.SetSite(this);
			}
			finally
			{
				if (pBuf != IntPtr.Zero)
				{
					Marshal.Release(pBuf);
				}
			}

			// assign our language service to the buffer
			Guid langService = typeof(FactLanguageService).GUID;
			ErrorHandler.ThrowOnFailure(lines.SetLanguageServiceID(ref langService));

			// Create a std code view (text)
			IntPtr srpCodeWin = IntPtr.Zero;
			iid = typeof(IVsCodeWindow).GUID;

			// create code view (does CoCreateInstance if not in shell's registry)
			ErrorHandler.ThrowOnFailure(locReg.CreateInstance(
				typeof(VsCodeWindowClass).GUID,
				null,
				ref iid,
				(uint)OleInterop.CLSCTX.CLSCTX_INPROC_SERVER,
				out srpCodeWin));

			IVsCodeWindow codeWindow = null;
			try
			{
				// Get an object to tie to the IDE
				codeWindow = (IVsCodeWindow)Marshal.GetObjectForIUnknown(srpCodeWin);
			}
			finally
			{
				if (srpCodeWin != IntPtr.Zero)
				{
					Marshal.Release(srpCodeWin);
				}
			}

			ErrorHandler.ThrowOnFailure(codeWindow.SetBuffer(lines));

			IVsWindowFrame windowFrame;
			IVsUIShell shell = (IVsUIShell)GetService(typeof(IVsUIShell));
			Guid emptyGuid = new Guid();
			Guid factEditorToolWindowGuid = FactGuidList.FactEditorToolWindowGuid;
			// CreateToolWindow ARGS
			// 0 - toolwindow.flags (initnew)
			// 1 - 0 (the tool window ID)
			// 2- IVsWindowPane
			// 3- guid null
			// 4- persistent slot (same nr as the guid attr on tool window class)
			// 5- guid null
			// 6- ole service provider (null)
			// 7- tool window.windowTitle
			// 8- int[] for position (empty array)
			// 9- out IVsWindowFrame
			ErrorHandler.ThrowOnFailure(shell.CreateToolWindow(
				(uint)__VSCREATETOOLWIN.CTW_fInitNew, // tool window flags, default to init new
				0,
				(IVsWindowPane)codeWindow,
				ref emptyGuid,
				ref factEditorToolWindowGuid,
				ref emptyGuid,
				null,
				ResourceStrings.FactEditorToolWindowCaption,
				null,
				out windowFrame));

			return windowFrame;
		}
		#endregion FactEditorToolWindow Creation
		#region IVsInstalledProduct Members

		[Obsolete("Visual Studio 2005 no longer calls this method.", true)]
		int IVsInstalledProduct.IdBmpSplash(out uint pIdBmp)
		{
			pIdBmp = (uint)UIntPtr.Zero;
			return VSConstants.E_NOTIMPL;
		}

		int IVsInstalledProduct.IdIcoLogoForAboutbox(out uint pIdIco)
		{
			// UNDONE: replace hard-coded ID for AboutBox icon
			pIdIco = 110;
			return VSConstants.S_OK;
		}

		int IVsInstalledProduct.OfficialName(out string pbstrName)
		{
			pbstrName = ResourceStrings.PackageOfficialName;
			return VSConstants.S_OK;
		}

		int IVsInstalledProduct.ProductDetails(out string pbstrProductDetails)
		{
			pbstrProductDetails = ResourceStrings.PackageProductDetails;
			return VSConstants.S_OK;
		}

		int IVsInstalledProduct.ProductID(out string pbstrPID)
		{
			pbstrPID = Assembly.GetExecutingAssembly().GetName().Version.ToString();
			return VSConstants.S_OK;
		}

#endregion
		#region Tool Window properties
		/// <summary>
		/// Browser tool window.
		/// </summary>
		public static ORMBrowserToolWindow BrowserWindow
		{
			get
			{
				return (ORMBrowserToolWindow)mySingleton.GetToolWindow(typeof(ORMBrowserToolWindow), true);
			}
		}

		/// <summary>
		/// Reading editor tool window.
		/// </summary>
		public static ORMReadingEditorToolWindow ReadingEditorWindow
		{
			get
			{
				return (ORMReadingEditorToolWindow)mySingleton.GetToolWindow(typeof(ORMReadingEditorToolWindow), true);
			}
		}
		/// <summary>
		/// The reference mode editor window.
		/// </summary>
		public static ORMReferenceModeEditorToolWindow ReferenceModeEditorWindow
		{
			get
			{
				return (ORMReferenceModeEditorToolWindow)mySingleton.GetToolWindow(typeof(ORMReferenceModeEditorToolWindow), true);
			}
		}

		/// <summary>
		/// Fact editor tool window.
		/// </summary>
		public static IVsWindowFrame FactEditorWindow
		{
			get
			{
				return mySingleton.EnsureFactEditorToolWindow();
			}
		}

		/// <summary>
		/// Verbalization output tool window.
		/// </summary>
		public static ORMVerbalizationToolWindow VerbalizationWindow
		{
			get
			{
				return (ORMVerbalizationToolWindow)mySingleton.GetToolWindow(typeof(ORMVerbalizationToolWindow), true);
			}
		}
		/// <summary>
		/// Called if the verbalization window settings change in the options dialog.
		/// Does nothing if the window has not been created.
		/// </summary>
		public static void VerbalizationWindowSettingsChanged()
		{
			if (mySingleton != null)
			{
				ORMVerbalizationToolWindow window = (ORMVerbalizationToolWindow)mySingleton.GetToolWindow(typeof(ORMVerbalizationToolWindow), false);
				if (window != null)
				{
					window.SettingsChanged();
				}
			}
		}
		#endregion

		#region Global SubStores
		private static Type[] myGlobalSubStores;
		/// <summary>
		/// Gets a <see cref="Type"/><see cref="Array">[]</see> of the core ORM Designer
		/// <see cref="SubStore"/>s, including <see cref="SubStore"/>s contained within
		/// any registered extensions.
		/// </summary>
		/// <returns>
		/// An array of the <see cref="Type"/>s of all loaded <see cref="SubStore"/>s,
		/// or <see langword="null"/> if an <see cref="ORMDesignerPackage"/> has not been
		/// instantiated by the host application.
		/// </returns>
		public static Type[] GetGlobalSubStores()
		{
			if (Singleton == null)
			{
				return null;
			}

			// If we haven't yet obtained the array of SubStores, do so...
			if (myGlobalSubStores == null)
			{
				List<Type> subStoreTypes = new List<Type>();
				subStoreTypes.Add(typeof(Microsoft.VisualStudio.Modeling.Diagrams.CoreDesignSurface));
				subStoreTypes.Add(typeof(ObjectModel.ORMMetaModel));
				subStoreTypes.Add(typeof(ShapeModel.ORMShapeModel));
				GetExtensionSubStores(subStoreTypes);
				myGlobalSubStores = subStoreTypes.ToArray();
			}

			// Return a copy of the array, so that if the caller modifies it, it won't affect any other callers
			return myGlobalSubStores.Clone() as Type[];
		}
		/// <summary>
		/// Retrieves the <see cref="SubStore"/>s from all registered extensions,
		/// and adds them to the <see cref="ICollection{Type}"/> <paramref name="extensionSubStoreTypes"/>.
		/// </summary>
		/// <param name="extensionSubStoreTypes">
		/// The <see cref="ICollection{Type}"/> to which the extension <see cref="SubStore"/>s
		/// should be added.
		/// </param>
		private static void GetExtensionSubStores(ICollection<Type> extensionSubStoreTypes)
		{
			RegistryKey applicationRegistryRoot = null;
			RegistryKey userRegistryRoot = null;
			try
			{
				applicationRegistryRoot = mySingleton.ApplicationRegistryRoot;
				userRegistryRoot = mySingleton.UserRegistryRoot;

				// Get the application (all users) extensions
				LoadExtensions(extensionSubStoreTypes, applicationRegistryRoot, REGISTRYROOT_EXTENSIONS);

				// Get the per-user extensions
				LoadExtensions(extensionSubStoreTypes, userRegistryRoot, REGISTRYROOT_EXTENSIONS);
			}
			finally
			{
				if (applicationRegistryRoot != null)
				{
					applicationRegistryRoot.Close();
				}
				if (userRegistryRoot != null)
				{
					userRegistryRoot.Close();
				}
			}
		}
		/// <summary>
		/// Adds the extension <see cref="SubStore"/> <see cref="Type"/>s from the <paramref name="extensionPath"/>
		/// under <paramref name="hkeyBase"/> to the <see cref="ICollection{Type}"/> <paramref name="extensionSubStoreTypes"/>.
		/// </summary>
		private static void LoadExtensions(ICollection<Type> extensionSubStoreTypes, RegistryKey hkeyBase, string extensionPath)
		{
			RegistryKey hkeyExtensions = null;
			try
			{
				hkeyExtensions = hkeyBase.OpenSubKey(extensionPath, RegistryKeyPermissionCheck.ReadSubTree);

				if (hkeyExtensions != null)
				{
					foreach (string extensionKeyName in hkeyExtensions.GetSubKeyNames())
					{
						using (RegistryKey hkeyExtension = hkeyExtensions.OpenSubKey(extensionKeyName, RegistryKeyPermissionCheck.ReadSubTree))
						{
							if (hkeyExtension != null)
							{
							// Execution is returned to this point if the user elects to retry a failed extension load
							LABEL_RETRY:
								try
								{
									Assembly extensionAssembly = null;
									string extension;

									// First see if the extension is in the GAC, and if it is, load it from there
									if ((extension = hkeyExtension.GetValue("AssemblyGacName") as string) != null)
									{
										extensionAssembly = Assembly.Load(extension);
									}
									// If it isn't in the GAC, see if it is in a file
									else if ((extension = hkeyExtension.GetValue("AssemblyFilePath") as string) != null)
									{
										extensionAssembly = Assembly.LoadFrom(extension);
									}

									// If we found and loaded an Assembly for the extension, check each Type in it
									// to find any SubStores
									if (extensionAssembly != null)
									{
										foreach (Type type in extensionAssembly.GetTypes())
										{
											if (type.IsSubclassOf(typeof(SubStore)))
											{
												extensionSubStoreTypes.Add(type);
											}
										}
									}
								}
								catch (SystemException ex)
								{
									// A SystemException can occur for a number of reasons, including the user not having the correct
									// registry or file permissions or the referenced assmebly or file not existing or being corrupt

									// Get the IVsUIShell from the Singleton
									IVsUIShell vsUIShell = Singleton.GetService(typeof(SVsUIShell)) as IVsUIShell;
									Debug.Assert(vsUIShell != null);	// vsUIShell will only be null if it cannot be found, which normally should not happen

									// UNDONE: Retrieve a localized format string from a resource and use that as the message
									string message = string.Format(System.Globalization.CultureInfo.CurrentUICulture,
										"ORM Designer extension '{1}' failed to load.{0}{0}" +
										"{0}----BEGIN EXCEPTION----{0}{0}{2}{0}----END EXCEPTION----{0}{0}{0}" +
										"Abort  = Allow ORM Designer package load to fail and signal a breakpoint{0}" +
										"Retry  = Retry loading the extension{0}" +
										"Ignore = Ignore the extension load failure and continue with the next extension{0}",
										Environment.NewLine, extensionKeyName, ex);
									int pnResult;
									uint notUsedUInt32 = 0;
									Guid notUsedGuid = Guid.Empty;
									ErrorHandler.ThrowOnFailure(vsUIShell.ShowMessageBox(notUsedUInt32, ref notUsedGuid, "Extension Load Failure", message, String.Empty, notUsedUInt32, OLEMSGBUTTON.OLEMSGBUTTON_ABORTRETRYIGNORE, OLEMSGDEFBUTTON.OLEMSGDEFBUTTON_THIRD, OLEMSGICON.OLEMSGICON_WARNING, Convert.ToInt32(false), out pnResult));
									if (pnResult == (int)DialogResult.Retry)
									{
										goto LABEL_RETRY;
									}
									else if (pnResult != (int)DialogResult.Ignore)
									{
										// If a debugger is already attached, Launch() has no effect, so we can always safely call it
										Debugger.Launch();
										Debugger.Break();
										throw;
									}
								}
							}
						}
					}
				}
			}
			catch (System.Security.SecurityException ex)
			{
				// Ignore any SecurityException that occurs if the user does not have permission to read the RegistryKey.
				// NOTE: In theory, this should never happen
				Debug.Assert(false, "A SecurityException was thrown while accessing the Registry:" + Environment.NewLine + ex);
			}
			finally
			{
				if (hkeyExtensions != null)
				{
					hkeyExtensions.Close();
				}
			}
		}
		#endregion // Global SubStores
	}
}
