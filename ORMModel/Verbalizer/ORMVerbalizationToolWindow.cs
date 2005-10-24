using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.ComponentModel.Design;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using Microsoft.VisualStudio.Modeling;
using Microsoft.VisualStudio.EnterpriseTools.Shell;
using Microsoft.VisualStudio.Shell.Interop;
using Neumont.Tools.ORM.ObjectModel;

namespace Neumont.Tools.ORM.Shell
{
	/// <summary>
	/// ToolWindow for hosting a web browser for verbalizations
	/// </summary>
	[Guid("C9AA5E71-9193-46c9-971A-CB6365ACA338")]
	[CLSCompliant(false)]
	public class ORMVerbalizationToolWindow : ToolWindow
	{
		#region Constants
		// UNDONE: Move these constants outside of the compiled code
		private const string HtmlNewLine = "<br/>\n";
		private const string HtmlIncreaseIndent = @"<span class=""indent"">";
		private const string HtmlDecreaseIndent = @"</span>";
		private const string HtmlOpenNewVerbalization = @"<p class=""verbalization"">";
		private const string HtmlCloseNewVerbalization = @"</p>";
		private const string HtmlErrorTagOpen = @"<span class=""error"">";
		private const string HtmlErrorTagClose = @"</span>";
		private const string HtmlHeader = @"
<!DOCTYPE HTML PUBLIC ""-//W3C//DTD HTML 4.0 Transitional//EN"">
<html>
	<head>
		<title>ORM2 Verbalization</title>
		<style>
			body { font-family: Tahoma; font-size: 8pt; padding: 10px; }
			td{ font-family: Tahoma; font-size: 8pt; }
			.objectType { color: #ff0000; font-weight: bold; }
			.objectTypeMissing { font-weight: bold; }
			.referenceMode { color: #840084; font-weight: bold; }
			.predicateText { color: #0000ff; }
			.quantifier { color: #00a500; }
			.error { color: red; }
			.verbalization { }
			.indent { left: 20px; position: relative; }
			.smallIndent { left: 8px; position: relative; }
			.listSeparator { color: windowtext; font-weight: 200;}
		</style>
	</head>
	<body>
";
		private const string HtmlFooter = @"</body></html>";
		#endregion // Constants
		#region Member variables
		private WebBrowser myWebBrowser;
		private ORMDesignerDocView myCurrentDocumentView;
		private bool myShowNegativeVerbalizations;
		private StringWriter myStringWriter;

		/// <summary>
		/// Callback for child verbalizations
		/// </summary>
		private delegate bool VerbalizationHandler(IVerbalize verbalizer, int indentationLevel);
		#endregion // Member variables
		#region Accessor Properties
		/// <summary>
		/// Show negative verbalizations if available
		/// </summary>
		public bool ShowNegativeVerbalizations
		{
			get
			{
				return myShowNegativeVerbalizations;
			}
			set
			{
				if (myShowNegativeVerbalizations != value)
				{
					myShowNegativeVerbalizations = value;
					UpdateVerbalization();
				}
			}
		}
		#endregion // Accessor Properties
		#region Construction
		/// <summary>
		/// Construct a verbalization window with a monitor selection service
		/// </summary>
		/// <param name="serviceProvider">Service provider</param>
		public ORMVerbalizationToolWindow(IServiceProvider serviceProvider)
			: base(serviceProvider)
		{
			// create the string writer to hold the html
			StringBuilder builder = new StringBuilder();
			myStringWriter = new StringWriter(builder, CultureInfo.CurrentUICulture);
			myStringWriter.NewLine = HtmlNewLine;

			IMonitorSelectionService monitor = (IMonitorSelectionService)serviceProvider.GetService(typeof(IMonitorSelectionService));
			monitor.DocumentWindowChanged += new MonitorSelectionEventHandler(DocumentWindowChangedEvent);
			monitor.SelectionChanged += new MonitorSelectionEventHandler(SelectionChangedEvent);
			CurrentDocumentView = monitor.CurrentDocumentView as ORMDesignerDocView;
		}
		/// <summary>
		/// Initialize here after we have the frame so we can grab the toolbar host
		/// </summary>
		protected override void Initialize()
		{
			base.Initialize();
			IVsToolWindowToolbarHost host = ToolbarHost;
			Debug.Assert(host != null); // Should be set with HasToolbar true
			if (host != null)
			{
				CommandID command = ORMDesignerDocView.ORMDesignerCommandIds.VerbalizationToolBar;
				Guid commandGuid = command.Guid;
				host.AddToolbar(VSTWT_LOCATION.VSTWT_LEFT, ref commandGuid, (uint)command.ID);
			}
		}
		/// <summary>
		/// Make sure the toolbar flag gets set
		/// </summary>
		protected override bool HasToolbar
		{
			get
			{
				return true;
			}
		}
		#endregion // Construction
		#region Selection monitor event handlers and helpers
		private void DocumentWindowChangedEvent(object sender, MonitorSelectionEventArgs e)
		{
			CurrentDocumentView = ((IMonitorSelectionService)sender).CurrentDocumentView as ORMDesignerDocView;
		}
		private void SelectionChangedEvent(object sender, MonitorSelectionEventArgs e)
		{
			UpdateVerbalization();
		}
		private void ModelStateChangedEvent(object sender, ElementEventsEndedEventArgs e)
		{
			UpdateVerbalization();
		}
		private ORMDesignerDocView CurrentDocumentView
		{
			get
			{
				return myCurrentDocumentView;
			}
			set
			{
				ORMDesignerDocView oldView = myCurrentDocumentView;
				if (oldView != null)
				{
					ORMDesignerDocData oldDoc = oldView.DocData as ORMDesignerDocData;
					if (value != null)
					{
						if (object.ReferenceEquals(oldView, value))
						{
							return;
						}
						else if (object.ReferenceEquals(oldDoc, value.DocData))
						{
							myCurrentDocumentView = value;
							return;
						}
					}
					if (oldDoc != null)
					{
						Store store = oldDoc.Store;
						if (store != null && !store.Disposed)
						{
							store.EventManagerDirectory.ElementEventsEnded.Remove(new ElementEventsEndedEventHandler(ModelStateChangedEvent));
						}
					}
				}
				myCurrentDocumentView = value;
				if (value != null)
				{
					ORMDesignerDocData docData = value.DocData as ORMDesignerDocData;
					if (docData != null)
					{
						docData.Store.EventManagerDirectory.ElementEventsEnded.Add(new ElementEventsEndedEventHandler(ModelStateChangedEvent));
					}
				}
			}
		}
		#endregion // Selection monitor event handlers and helpers
		#region Overrides
		/// <summary>
		/// Gets the title that will be displayed on the tool window.
		/// </summary>
		public override string WindowTitle
		{
			get
			{
				return ResourceStrings.ModelVerbalizationWindowTitle;
			}
		}

		/// <summary>
		/// Gets the web browser control hosted in the tool window
		/// </summary>
		public override IWin32Window Window
		{
			get 
			{
				WebBrowser browser = myWebBrowser;
				if (browser == null)
				{
					myWebBrowser = browser = new WebBrowser();
					browser.Dock = DockStyle.Fill;
					StringWriter writer = myStringWriter;
					browser.DocumentText = (writer != null) ? writer.ToString() : "";
					// The container magically provides resize support, we don't have
					// to go all the way to a form
					ContainerControl container = new ContainerControl();
					container.Controls.Add(browser);
				}
				return browser.Parent;
			}
		}
		/// <summary>
		/// Clean up any existing objects
		/// </summary>
		/// <param name="disposing"></param>
		protected override void Dispose(bool disposing)
		{
			base.Dispose(disposing);
			if (disposing)
			{
				// TODO: Remove event handlers for monitor selection
				if (myWebBrowser != null)
				{
					(myWebBrowser as IDisposable).Dispose();
					myWebBrowser = null;
				}
				if (myStringWriter != null)
				{
					(myStringWriter as IDisposable).Dispose();
					myStringWriter = null;
				}
			}
		}
		#endregion // Overrides
		#region Verbalization Implementation
		private void UpdateVerbalization()
		{
			ORMDesignerDocView theView = CurrentDocumentView;
			if (theView == null)
			{
				return;
			}

			myStringWriter.GetStringBuilder().Length = 0;

			ICollection selectedObjects = theView.GetSelectedComponents();
			bool showNegative = myShowNegativeVerbalizations;
			bool firstCallPending = true;
			foreach (ModelElement melIter in selectedObjects)
			{
				ModelElement mel = melIter;
				PresentationElement pel = mel as PresentationElement;
				if (pel != null)
				{
					mel = pel.ModelElement;
				}
				if (mel != null)
				{
					VerbalizeElement(mel, showNegative, myStringWriter, ref firstCallPending);
				}
			}
			if (!firstCallPending)
			{
				// Write footer
				myStringWriter.Write(HtmlFooter);
			}
			else
			{
				// Nothing happened, put in text for nothing happened
			}
			WebBrowser browser = myWebBrowser;
			if (browser != null)
			{
				browser.DocumentText = myStringWriter.ToString();
			}
		}
		/// <summary>
		/// Determine the indentation level for verbalizing a ModelElement, and fire
		/// the delegate for verbalization
		/// </summary>
		/// <param name="element">The element to verbalize</param>
		/// <param name="isNegative">Use the negative form of the reading</param>
		/// <param name="writer">The TextWriter for verbalization output</param>
		/// <param name="firstCallPending"></param>
		private static void VerbalizeElement(ModelElement element, bool isNegative, TextWriter writer, ref bool firstCallPending)
		{
			int lastLevel = 0;
			bool firstWrite = true;
			bool localFirstCallPending = firstCallPending;
			VerbalizeElement(
				element,
				delegate(IVerbalize verbalizer, int indentationLevel)
				{
					bool openedErrorReport = false;
					bool retVal = verbalizer.GetVerbalization(
						writer,
						delegate(VerbalizationContent content)
						{
							if (content == VerbalizationContent.ErrorReport)
							{
								// spit opening tag for text denoting an error
								openedErrorReport = true;
								writer.Write(HtmlErrorTagOpen);
							}

							// Prepare for verbalization on this element. Everything
							// is delayed to this point in case the verbalization implementation
							// does not callback to the text writer.
							if (firstWrite)
							{
								if (localFirstCallPending)
								{
									localFirstCallPending = false;
									// Write the HTML header to the buffer
									writer.Write(HtmlHeader);
								}

								// write open tag for new verbalization
								writer.Write(HtmlOpenNewVerbalization);

								localFirstCallPending = false;
								firstWrite = false;
							}
							else
							{
								writer.WriteLine();
							}


							// Write indentation tags as needed
							if (indentationLevel > lastLevel)
							{
								do
								{
									writer.Write(HtmlIncreaseIndent);
									++lastLevel;
								} while (lastLevel != indentationLevel);
							}
							else if (lastLevel > indentationLevel)
							{
								do
								{
									writer.Write(HtmlDecreaseIndent);
									--lastLevel;
								} while (lastLevel != indentationLevel);
							}
						},
						isNegative);
					if (openedErrorReport)
					{
						// Close error report tag
						writer.Write(HtmlErrorTagClose);
					}
					return retVal;
				},
				0);
			while (lastLevel > 0)
			{
				writer.Write(HtmlDecreaseIndent);
				--lastLevel;
			}
			// close the opening tag for the new verbalization
			if (!firstWrite)
			{
				writer.Write(HtmlCloseNewVerbalization);
			}
			firstCallPending = localFirstCallPending;
		}
		/// <summary>
		/// Verbalize the passed in element and all its children
		/// </summary>
		private static void VerbalizeElement(ModelElement element, VerbalizationHandler callback, int indentLevel)
		{
			IVerbalize parentVerbalize = element as IVerbalize;
			if (parentVerbalize == null && indentLevel == 0)
			{
				IRedirectVerbalization surrogateRedirect = element as IRedirectVerbalization;
				if (surrogateRedirect != null)
				{
					parentVerbalize = surrogateRedirect.SurrogateVerbalizer;
					if (parentVerbalize != null)
					{
						element = parentVerbalize as ModelElement;
					}
				}
			}
			if (parentVerbalize != null)
			{
				if (callback(parentVerbalize, indentLevel) && element != null)
				{
					++indentLevel;
					IList aggregateList = element.MetaClass.AggregatedRoles;
					int aggregateCount = aggregateList.Count;
					for (int i = 0; i < aggregateCount; ++i)
					{
						MetaRoleInfo roleInfo = (MetaRoleInfo)aggregateList[i];
						IList children = element.GetCounterpartRolePlayers(roleInfo.OppositeMetaRole, roleInfo, false);
						int childCount = children.Count;
						for (int j = 0; j < childCount; ++j)
						{
							VerbalizeElement((ModelElement)children[j], callback, indentLevel);
						}
					}
				}
			}
		}
		#endregion // Verbalization Implementation
	}
}