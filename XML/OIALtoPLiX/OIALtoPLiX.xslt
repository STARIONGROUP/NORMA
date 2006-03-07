<?xml version="1.0" encoding="utf-8" ?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:exsl="http://exslt.org/common"
	xmlns:oil="http://schemas.orm.net/OIAL"
	xmlns:odt="http://schemas.orm.net/ORMDataTypes"
	xmlns:plx="http://schemas.neumont.edu/CodeGeneration/PLiX"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:prop="urn:schemas-orm-net:PLiX:CLI:Properties">

	<xsl:output method="xml" encoding="utf-8" indent="yes"/>

	<xsl:include href="GenerateGlobalSupportClasses.xslt"/>

	<xsl:param name="GenerateGlobalSupportClasses" select="false()"/>
	<xsl:param name="GenerateCodeAnalysisAttributes" select="false()"/>
	<xsl:param name="RaiseEventsAsynchronously" select="true()"/>
	<xsl:param name="CustomToolNamespace" select="'TestNamespace'"/>
	<xsl:param name="PrivateMemberPrefix" select="'_'"/>
	<xsl:param name="ImplementationClassSuffix" select="'Core'"/>
	<xsl:param name="ModelContextInterfaceImplementationVisibility" select="'public'"/>

	<xsl:template name="GenerateCLSCompliantAttributeIfNecessary">
		<xsl:variable name="dataTypeFragment">
			<xsl:choose>
				<xsl:when test="string-length(@dataTypeName)">
					<xsl:copy-of select="."/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:copy-of select="prop:DataType"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="dataType" select="exsl:node-set($dataTypeFragment)/child::*"/>
		<xsl:choose>
			<xsl:when test="starts-with($dataType/@dataTypeName,'.u')">
				<plx:attribute dataTypeName="CLSCompliantAttribute">
					<plx:passParam>
						<plx:falseKeyword/>
					</plx:passParam>
				</plx:attribute>
			</xsl:when>
			<xsl:otherwise>
				<xsl:for-each select="$dataType/child::*">
					<xsl:call-template name="GenerateCLSCompliantAttributeIfNecessary"/>
				</xsl:for-each>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="GenerateSuppressMessageAttribute">
		<xsl:param name="category"/>
		<xsl:param name="checkId"/>
		<xsl:param name="justification"/>
		<xsl:param name="messageId"/>
		<xsl:param name="scope"/>
		<xsl:param name="target"/>
		<xsl:if test="$GenerateCodeAnalysisAttributes">
			<plx:attribute dataTypeName="SuppressMessageAttribute" dataTypeQualifier="System.Diagnostics.CodeAnalysis">
				<plx:passParam>
					<plx:string>
						<xsl:value-of select="$category"/>
					</plx:string>
				</plx:passParam>
				<plx:passParam>
					<plx:string>
						<xsl:value-of select="$checkId"/>
					</plx:string>
				</plx:passParam>
				<xsl:if test="$justification">
					<plx:passParam>
						<plx:binaryOperator type="assignNamed">
							<plx:left>
								<plx:nameRef type="namedParameter" name="Justification"/>
							</plx:left>
							<plx:right>
								<plx:string>
									<xsl:value-of select="$justification"/>
								</plx:string>
							</plx:right>
						</plx:binaryOperator>
					</plx:passParam>
				</xsl:if>
				<xsl:if test="$messageId">
					<plx:passParam>
						<plx:binaryOperator type="assignNamed">
							<plx:left>
								<plx:nameRef type="namedParameter" name="MessageId"/>
							</plx:left>
							<plx:right>
								<plx:string>
									<xsl:value-of select="$messageId"/>
								</plx:string>
							</plx:right>
						</plx:binaryOperator>
					</plx:passParam>
				</xsl:if>
				<xsl:if test="$scope">
					<plx:passParam>
						<plx:binaryOperator type="assignNamed">
							<plx:left>
								<plx:nameRef type="namedParameter" name="Scope"/>
							</plx:left>
							<plx:right>
								<plx:string>
									<xsl:value-of select="$scope"/>
								</plx:string>
							</plx:right>
						</plx:binaryOperator>
					</plx:passParam>
				</xsl:if>
				<xsl:if test="$target">
					<plx:passParam>
						<plx:binaryOperator type="assignNamed">
							<plx:left>
								<plx:nameRef type="namedParameter" name="Target"/>
							</plx:left>
							<plx:right>
								<plx:string>
									<xsl:value-of select="$target"/>
								</plx:string>
							</plx:right>
						</plx:binaryOperator>
					</plx:passParam>
				</xsl:if>
			</plx:attribute>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="/">
		<plx:root>
			<plx:namespaceImport name="System"/>
			<plx:namespaceImport name="System.Collections.Generic"/>
			<plx:namespaceImport name="System.Collections.ObjectModel"/>
			<plx:namespaceImport name="System.ComponentModel"/>
			<plx:namespaceImport name="System.Xml"/>
			<xsl:if test="$GenerateGlobalSupportClasses='true'">
				<xsl:call-template name="GenerateGlobalSupportClasses"/>
			</xsl:if>
			<plx:namespace name="{$CustomToolNamespace}">
				<xsl:apply-templates mode="OIALtoPLiX" select="oil:model"/>
			</plx:namespace>
		</plx:root>
	</xsl:template>
	
	<xsl:template match="oil:model" mode="OIALtoPLiX">
		<xsl:variable name="Model" select="."/>
		<xsl:variable name="ModelName" select="$Model/@name"/>
		<xsl:variable name="ModelContextName" select="concat($ModelName,'Context')"/>
		<xsl:variable name="ConceptTypes" select="$Model//oil:conceptType"/>
		<xsl:variable name="InformationTypeFormatMappingsFragment">
			<xsl:apply-templates select="$Model/oil:informationTypeFormats/child::*" mode="GenerateInformationTypeFormatMapping"/>
		</xsl:variable>
		<xsl:variable name="InformationTypeFormatMappings" select="exsl:node-set($InformationTypeFormatMappingsFragment)/child::*"/>
		<xsl:variable name="AllPropertiesFragment">
			<xsl:variable name="ConceptTypeRefs" select="$Model//oil:conceptTypeRef"/>
			<xsl:for-each select="$ConceptTypes">
				<prop:Properties conceptTypeName="{@name}">
					<xsl:apply-templates select="." mode="GenerateProperties">
						<xsl:with-param name="ConceptTypeRefs" select="$ConceptTypeRefs"/>
						<xsl:with-param name="InformationTypeFormatMappings" select="$InformationTypeFormatMappings"/>
					</xsl:apply-templates>
				</prop:Properties>
			</xsl:for-each>
		</xsl:variable>
		<xsl:variable name="AllProperties" select="exsl:node-set($AllPropertiesFragment)/child::*"/>
		
		<plx:namespace name="{$ModelName}">

			<xsl:for-each select="$ConceptTypes">
				<xsl:apply-templates select="." mode="GenerateAbstractClass">
					<xsl:with-param name="Model" select="$Model"/>
					<xsl:with-param name="ModelContextName" select="$ModelContextName"/>
					<xsl:with-param name="InformationTypeFormatMappings" select="$InformationTypeFormatMappings"/>
					<xsl:with-param name="Properties" select="$AllProperties[@conceptTypeName=current()/@name]/prop:Property"/>
				</xsl:apply-templates>
			</xsl:for-each>
			
			<plx:interface visibility="public" name="I{$ModelContextName}">
				<plx:leadingInfo>
					<plx:pragma type="region" data="I{$ModelContextName}"/>
				</plx:leadingInfo>
				<plx:trailingInfo>
					<plx:pragma type="closeRegion" data="I{$ModelContextName}"/>
				</plx:trailingInfo>
				<xsl:call-template name="GenerateModelContextInterfaceMethods">
					<xsl:with-param name="Model" select="$Model"/>
					<xsl:with-param name="AllProperties" select="$AllProperties"/>
				</xsl:call-template>
				<xsl:for-each select="$ConceptTypes">
					<xsl:apply-templates select="." mode="GenerateModelContextInterfaceObjectMethods">
						<xsl:with-param name="Model" select="$Model"/>
						<xsl:with-param name="Properties" select="$AllProperties[@conceptTypeName=current()/@name]/prop:Property"/>
					</xsl:apply-templates>
				</xsl:for-each>
			</plx:interface>

			<xsl:apply-templates select="$Model" mode="OIALtoPLiX_Implementation">
				<xsl:with-param name="Model" select="$Model"/>
				<xsl:with-param name="ModelContextName" select="$ModelContextName"/>
				<xsl:with-param name="InformationTypeFormatMappings" select="$InformationTypeFormatMappings"/>
				<xsl:with-param name="AllProperties" select="$AllProperties"/>
			</xsl:apply-templates>
			
		</plx:namespace>
	</xsl:template>

	<xsl:template match="oil:conceptType" mode="GenerateProperties">
		<xsl:param name="ConceptTypeRefs"/>
		<xsl:param name="InformationTypeFormatMappings"/>
		<xsl:variable name="thisClassName" select="@name"/>

		<!--Process directly contained oil:conceptTypeRef and oil:informationType elements,
			as well as nested oil:conceptType elements and oil:conceptType elements that we are nested within.
			Also process all oil:conceptTypeRef elements that are targetted at us.-->

		<xsl:for-each select="oil:informationType">
			<prop:Property name="{@name}" mandatory="{@mandatory}" isUnique="{boolean(oil:singleRoleUniquenessConstraint)}" isCollection="false" isCustomType="false">
				<xsl:copy-of select="$InformationTypeFormatMappings[@name=current()/@formatRef]/prop:DataType"/>
			</prop:Property>
		</xsl:for-each>
		<xsl:for-each select="oil:conceptTypeRef">
			<prop:Property name="{@name}" mandatory="{@mandatory}" isUnique="{boolean(oil:singleRoleUniquenessConstraint)}" isCollection="false" isCustomType="true" oppositeName="{@oppositeName}">
				<prop:DataType dataTypeName="{@target}"/>
			</prop:Property>
		</xsl:for-each>
		<xsl:for-each select="oil:conceptType">
			<prop:Property name="{@name}" mandatory="{@mandatory}" isUnique="true" isCollection="false" isCustomType="true" oppositeName="{$thisClassName}">
				<prop:DataType dataTypeName="{@name}"/>
			</prop:Property>
		</xsl:for-each>
		<xsl:for-each select="parent::oil:conceptType">
			<prop:Property name="{@name}" mandatory="alethic" isUnique="true" isCollection="false" isCustomType="true" oppositeName="{$thisClassName}">
				<prop:DataType dataTypeName="{@name}"/>
			</prop:Property>
		</xsl:for-each>
		<xsl:for-each select="$ConceptTypeRefs[@target=current()/@name]">
			<prop:Property name="{@oppositeName}" mandatory="false" isUnique="true" isCollection="{not(boolean(oil:singleRoleUniquenessConstraint))}" isCustomType="true" oppositeName="{@name}">
				<prop:DataType dataTypeName="{parent::oil:conceptType/@name}"/>
			</prop:Property>
		</xsl:for-each>
	</xsl:template>
	<xsl:template match="*" mode="GenerateInformationTypeFormatMapping">
		<!--TODO:-->
		<FormatMapping name="{@name}">
			<prop:DataType dataTypeName=".string"/>
		</FormatMapping>
	</xsl:template>

	<xsl:template match="oil:conceptType" mode="GenerateAbstractClass">
		<xsl:param name="Model"/>
		<xsl:param name="ModelContextName"/>
		<xsl:param name="InformationTypeFormatMappings"/>
		<xsl:param name="Properties"/>
		<xsl:variable name="Events" select="$Properties[@isCollection='false']"/>
		<plx:class visibility="public" modifier="abstract" partial="true" name="{@name}">
			<plx:leadingInfo>
				<plx:pragma type="region" data="{@name}"/>
			</plx:leadingInfo>
			<plx:trailingInfo>
				<plx:pragma type="closeRegion" data="{@name}"/>
			</plx:trailingInfo>
			<plx:implementsInterface dataTypeName="INotifyPropertyChanged"/>
			<plx:function name=".construct" visibility="protected"/>
			<plx:field visibility="private" readOnly="true" name="Events" dataTypeIsSimpleArray="true" dataTypeName="Delegate">
				<plx:initialize>
					<plx:callNew dataTypeIsSimpleArray="true" dataTypeName="Delegate">
						<plx:passParam>
							<plx:value type="i4" data="{count($Events)+1}"/>
						</plx:passParam>
					</plx:callNew>
				</plx:initialize>
			</plx:field>
			<xsl:call-template name="GenerateINotifyPropertyChangedImplementation"/>
			<plx:property visibility="public" modifier="abstract" name="Context">
				<plx:returns dataTypeName="{$ModelContextName}"/>
				<plx:get/>
			</plx:property>
			<xsl:apply-templates select="$Events" mode="GeneratePropertyChangeEvents"/>
			<xsl:apply-templates select="$Properties" mode="GenerateAbstractProperty"/>
			<xsl:call-template name="GenerateToString">
				<xsl:with-param name="ClassName" select="@name"/>
				<xsl:with-param name="Properties" select="$Properties"/>
			</xsl:call-template>
		</plx:class>
	</xsl:template>
	<xsl:template match="prop:Property" mode="GenerateAbstractProperty">
		<plx:property visibility="public" modifier="abstract" name="{@name}" >
			<xsl:call-template name="GenerateCLSCompliantAttributeIfNecessary"/>
			<plx:returns>
				<xsl:copy-of select="prop:DataType/@*"/>
				<xsl:copy-of select="prop:DataType/child::*"/>
			</plx:returns>
			<plx:get/>
			<xsl:if test="not(@isCollection='true')">
				<plx:set/>
			</xsl:if>
		</plx:property>
	</xsl:template>

	<xsl:template match="prop:Property" mode="GeneratePropertyChangeEvents">
		<xsl:variable name="EventIndex" select="position()"/>
		<xsl:call-template name="GeneratePropertyChangeEvent">
			<xsl:with-param name="ChangeType" select="'Changing'"/>
			<xsl:with-param name="EventIndex" select="$EventIndex"/>
		</xsl:call-template>
		<xsl:call-template name="GeneratePropertyChangeEventRaiseMethod">
			<xsl:with-param name="ChangeType" select="'Changing'"/>
			<xsl:with-param name="EventIndex" select="$EventIndex"/>
		</xsl:call-template>
		<xsl:call-template name="GeneratePropertyChangeEvent">
			<xsl:with-param name="ChangeType" select="'Changed'"/>
			<xsl:with-param name="EventIndex" select="$EventIndex"/>
		</xsl:call-template>
		<xsl:call-template name="GeneratePropertyChangeEventRaiseMethod">
			<xsl:with-param name="ChangeType" select="'Changed'"/>
			<xsl:with-param name="EventIndex" select="$EventIndex"/>
		</xsl:call-template>
	</xsl:template>
	<xsl:template name="GeneratePropertyChangeEvent">
		<xsl:param name="ChangeType"/>
		<xsl:param name="EventIndex"/>
		<xsl:param name="IsPropertyChangedEvent" select="false()"/>
		<plx:event visibility="public" name="{@name}{$ChangeType}">
			<xsl:call-template name="GenerateCLSCompliantAttributeIfNecessary"/>
			<xsl:choose>
				<xsl:when test="$IsPropertyChangedEvent">
					<xsl:attribute name="visibility">privateInterfaceMember</xsl:attribute>
					<xsl:attribute name="name">PropertyChanged</xsl:attribute>
					<xsl:call-template name="GenerateSuppressMessageAttribute">
						<xsl:with-param name="category" select="'Microsoft.Design'"/>
						<xsl:with-param name="checkId" select="'CA1033'"/>
					</xsl:call-template>
					<plx:interfaceMember memberName="PropertyChanged" dataTypeName="INotifyPropertyChanged"/>
					<plx:explicitDelegateType dataTypeName="PropertyChangedEventHandler"/>
				</xsl:when>
				<xsl:otherwise>
					<plx:explicitDelegateType dataTypeName="EventHandler"/>
					<plx:passTypeParam  dataTypeName="Property{$ChangeType}EventArgs">
						<plx:passTypeParam>
							<xsl:copy-of select="prop:DataType/@*"/>
							<xsl:copy-of select="prop:DataType/child::*"/>
						</plx:passTypeParam>
					</plx:passTypeParam>
				</xsl:otherwise>
			</xsl:choose>
			<plx:onAdd>
				<xsl:call-template name="GetPropertyChangeEventOnAddRemoveCode">
					<xsl:with-param name="EventIndex" select="$EventIndex"/>
					<xsl:with-param name="MethodName" select="'Combine'"/>
				</xsl:call-template>
			</plx:onAdd>
			<plx:onRemove>
				<xsl:call-template name="GetPropertyChangeEventOnAddRemoveCode">
					<xsl:with-param name="EventIndex" select="$EventIndex"/>
					<xsl:with-param name="MethodName" select="'Remove'"/>
				</xsl:call-template>
			</plx:onRemove>
		</plx:event>
	</xsl:template>
	<xsl:template name="GetPropertyChangeEventOnAddRemoveCode">
		<xsl:param name="EventIndex"/>
		<xsl:param name="MethodName"/>
		<plx:assign>
			<plx:left>
				<plx:callInstance type="arrayIndexer" name=".implied">
					<plx:callObject>
						<plx:callThis accessor="this" type="field" name="Events"/>
					</plx:callObject>
					<plx:passParam>
						<plx:value type="i4" data="{$EventIndex}"/>
					</plx:passParam>
				</plx:callInstance>
			</plx:left>
			<plx:right>
				<plx:callStatic type="methodCall" name="{$MethodName}" dataTypeName="Delegate">
					<plx:passParam>
						<plx:callInstance type="arrayIndexer" name=".implied">
							<plx:callObject>
								<plx:callThis accessor="this" type="field" name="Events"/>
							</plx:callObject>
							<plx:passParam>
								<plx:value type="i4" data="{$EventIndex}"/>
							</plx:passParam>
						</plx:callInstance>
					</plx:passParam>
					<plx:passParam>
						<plx:valueKeyword/>
					</plx:passParam>
				</plx:callStatic>
			</plx:right>
		</plx:assign>
	</xsl:template>
	<xsl:template name="GeneratePropertyChangeEventRaiseMethod">
		<xsl:param name="ChangeType"/>
		<xsl:param name="EventIndex"/>
		<xsl:variable name="isChanging" select="$ChangeType='Changing'"/>
		<xsl:variable name="isChanged" select="$ChangeType='Changed'"/>
		<plx:function visibility="protected" name="Raise{@name}{$ChangeType}Event">
			<xsl:call-template name="GenerateCLSCompliantAttributeIfNecessary"/>
			<xsl:call-template name="GenerateSuppressMessageAttribute">
				<xsl:with-param name="category" select="'Microsoft.Design'"/>
				<xsl:with-param name="checkId" select="'CA1030'"/>
			</xsl:call-template>
			<xsl:choose>
				<xsl:when test="$isChanging">
					<plx:param name="newValue">
						<xsl:copy-of select="prop:DataType/@*"/>
						<xsl:copy-of select="prop:DataType/child::*"/>
					</plx:param>
					<plx:returns dataTypeName=".boolean"/>
				</xsl:when>
				<xsl:when test="$isChanged">
					<plx:param name="oldValue">
						<xsl:copy-of select="prop:DataType/@*"/>
						<xsl:copy-of select="prop:DataType/child::*"/>
					</plx:param>
				</xsl:when>
			</xsl:choose>
			<plx:local name="eventHandler" dataTypeName="EventHandler">
				<plx:passTypeParam dataTypeName="Property{$ChangeType}EventArgs">
					<plx:passTypeParam>
						<xsl:copy-of select="prop:DataType/@*"/>
						<xsl:copy-of select="prop:DataType/child::*"/>
					</plx:passTypeParam>
				</plx:passTypeParam>
				<plx:initialize>
					<plx:cast type="testCast" dataTypeName="EventHandler">
						<plx:passTypeParam dataTypeName="Property{$ChangeType}EventArgs">
							<plx:passTypeParam>
								<xsl:copy-of select="prop:DataType/@*"/>
								<xsl:copy-of select="prop:DataType/child::*"/>
							</plx:passTypeParam>
						</plx:passTypeParam>
						<plx:callInstance type="arrayIndexer" name=".implied">
							<plx:callObject>
								<plx:callThis name="Events" type="field"/>
							</plx:callObject>
							<plx:passParam>
								<plx:value type="i4" data="{$EventIndex}"/>
							</plx:passParam>
						</plx:callInstance>
					</plx:cast>
				</plx:initialize>
			</plx:local>
			<plx:branch>
				<plx:condition>
					<plx:binaryOperator type="identityInequality">
						<plx:left>
							<plx:nameRef name="eventHandler"/>
						</plx:left>
						<plx:right>
							<plx:nullKeyword/>
						</plx:right>
					</plx:binaryOperator>
				</plx:condition>
				<xsl:variable name="CreateNewEventArgs">
					<xsl:variable name="CurrentValue">
						<plx:callThis type="property"  name="{@name}"/>
					</xsl:variable>
					<plx:callNew dataTypeName="Property{$ChangeType}EventArgs">
						<plx:passTypeParam>
							<xsl:copy-of select="DataType/@*"/>
							<xsl:copy-of select="DataType/child::*"/>
						</plx:passTypeParam>
						<plx:passParam>
							<xsl:choose>
								<xsl:when test="$isChanging">
									<xsl:copy-of select="$CurrentValue"/>
								</xsl:when>
								<xsl:when test="$isChanged">
									<plx:nameRef name="oldValue"/>
								</xsl:when>
							</xsl:choose>
						</plx:passParam>
						<plx:passParam>
							<xsl:choose>
								<xsl:when test="$isChanging">
									<plx:nameRef name="newValue"/>
								</xsl:when>
								<xsl:when test="$isChanged">
									<xsl:copy-of select="$CurrentValue"/>
								</xsl:when>
							</xsl:choose>
						</plx:passParam>
					</plx:callNew>
				</xsl:variable>
				<xsl:if test="$isChanging">
					<plx:local name="eventArgs" dataTypeName="PropertyChangingEventArgs">
						<plx:passTypeParam>
							<xsl:copy-of select="prop:DataType/@*"/>
							<xsl:copy-of select="prop:DataType/child::*"/>
						</plx:passTypeParam>
						<plx:initialize>
							<xsl:copy-of select="$CreateNewEventArgs"/>
						</plx:initialize>
					</plx:local>
				</xsl:if>
				<xsl:variable name="commonCallCode">
					<plx:callObject>
						<plx:nameRef type="local" name="eventHandler"/>
					</plx:callObject>
					<plx:passParam>
						<plx:thisKeyword/>
					</plx:passParam>
					<plx:passParam>
						<xsl:choose>
							<xsl:when test="$isChanging">
								<plx:nameRef type="local" name="eventArgs"/>
							</xsl:when>
							<xsl:when test="$isChanged">
								<xsl:copy-of select="$CreateNewEventArgs"/>
							</xsl:when>
						</xsl:choose>
					</plx:passParam>
				</xsl:variable>
				<xsl:choose>
					<xsl:when test="$isChanging or not($RaiseEventsAsynchronously)">
						<plx:callInstance name=".implied" type="delegateCall">
							<xsl:copy-of select="$commonCallCode"/>
						</plx:callInstance>
					</xsl:when>
					<xsl:when test="$isChanged and $RaiseEventsAsynchronously">
						<plx:callInstance type="methodCall" name="BeginInvoke">
							<xsl:copy-of select="$commonCallCode"/>
							<plx:passParam>
								<plx:callNew type="newDelegate" dataTypeName="AsyncCallback" dataTypeQualifier="System">
									<plx:passParam>
										<plx:callInstance type="methodReference" name="EndInvoke">
											<plx:callObject>
												<plx:nameRef type="local" name="eventHandler"/>
											</plx:callObject>
										</plx:callInstance>
									</plx:passParam>
								</plx:callNew>
							</plx:passParam>
							<plx:passParam>
								<plx:nullKeyword/>
							</plx:passParam>
						</plx:callInstance>
					</xsl:when>
				</xsl:choose>
				<xsl:choose>
					<xsl:when test="$isChanging">
						<plx:return>
							<plx:unaryOperator type="booleanNot">
								<plx:callInstance name="Cancel" type="property">
									<plx:callObject>
										<plx:nameRef name="eventArgs"/>
									</plx:callObject>
								</plx:callInstance>
							</plx:unaryOperator>
						</plx:return>
					</xsl:when>
					<xsl:when test="$isChanged">
						<plx:callThis name="RaisePropertyChangedEvent">
							<plx:passParam>
								<plx:string>
									<xsl:value-of select="@name"/>
								</plx:string>
							</plx:passParam>
						</plx:callThis>
					</xsl:when>
				</xsl:choose>
			</plx:branch>
			<xsl:if test="$isChanging">
				<plx:return>
					<plx:trueKeyword/>
				</plx:return>
			</xsl:if>
		</plx:function>
	</xsl:template>
	<xsl:template name="GenerateINotifyPropertyChangedImplementation">
		<xsl:call-template name="GeneratePropertyChangeEvent">
			<xsl:with-param name="ChangeType" select="'Changed'"/>
			<xsl:with-param name="EventIndex" select="0"/>
			<xsl:with-param name="IsPropertyChangedEvent" select="true()"/>
		</xsl:call-template>
		<plx:function visibility="private" name="RaisePropertyChangedEvent">
			<plx:param name="propertyName" dataTypeName=".string"/>
			<plx:local name="eventHandler" dataTypeName="PropertyChangedEventHandler">
				<plx:initialize>
					<plx:cast type="testCast" dataTypeName="PropertyChangedEventHandler">
						<plx:callInstance type="arrayIndexer" name=".implied">
							<plx:callObject>
								<plx:callThis name="Events" type="field"/>
							</plx:callObject>
							<plx:passParam>
								<plx:value type="i4" data="0"/>
							</plx:passParam>
						</plx:callInstance>
					</plx:cast>
				</plx:initialize>
			</plx:local>
			<plx:branch>
				<plx:condition>
					<plx:binaryOperator type="identityInequality">
						<plx:left>
							<plx:nameRef type="local" name="eventHandler"/>
						</plx:left>
						<plx:right>
							<plx:nullKeyword/>
						</plx:right>
					</plx:binaryOperator>
				</plx:condition>
				<xsl:variable name="commonCallCode">
					<plx:callObject>
						<plx:nameRef type="local" name="eventHandler"/>
					</plx:callObject>
					<plx:passParam>
						<plx:thisKeyword/>
					</plx:passParam>
					<plx:passParam>
						<plx:callNew dataTypeName="PropertyChangedEventArgs">
							<plx:passParam>
								<plx:nameRef type="parameter" name="propertyName"/>
							</plx:passParam>
						</plx:callNew>
					</plx:passParam>
				</xsl:variable>
				<xsl:choose>
					<xsl:when test="$RaiseEventsAsynchronously">
						<plx:callInstance type="methodCall" name="BeginInvoke">
							<xsl:copy-of select="$commonCallCode"/>
							<plx:passParam>
								<plx:callNew type="newDelegate" dataTypeName="AsyncCallback">
									<plx:passParam>
										<plx:callInstance type="methodReference" name="EndInvoke">
											<plx:callObject>
												<plx:nameRef type="local" name="eventHandler"/>
											</plx:callObject>
										</plx:callInstance>
									</plx:passParam>
								</plx:callNew>
							</plx:passParam>
							<plx:passParam>
								<plx:nullKeyword/>
							</plx:passParam>
						</plx:callInstance>
					</xsl:when>
					<xsl:otherwise>
						<plx:callInstance name=".implied" type="delegateCall">
							<xsl:copy-of select="$commonCallCode"/>
						</plx:callInstance>
					</xsl:otherwise>
				</xsl:choose>
			</plx:branch>
		</plx:function>
	</xsl:template>

	<xsl:template name="GenerateToString">
		<xsl:param name="ClassName"/>
		<xsl:param name="Properties"/>
		<xsl:variable name="NonCollectionProperties" select="$Properties[not(@isCollection='true')]"/>
		<plx:function visibility="public" modifier="sealedOverride" overload="true" name="ToString">
			<plx:returns dataTypeName=".string"/>
			<plx:return>
				<plx:callThis accessor="this" type="methodCall" name="ToString">
					<plx:passParam>
						<plx:nullKeyword/>
					</plx:passParam>
				</plx:callThis>
			</plx:return>
		</plx:function>
		<plx:function visibility="public" overload="true" name="ToString">
			<plx:param type="in" name="provider" dataTypeName="IFormatProvider"/>
			<plx:returns dataTypeName=".string"/>
			<plx:return>
				<plx:callStatic name="Format" dataTypeName=".string">
					<plx:passParam>
						<plx:nameRef type="parameter" name="provider"/>
					</plx:passParam>
					<plx:passParam>
						<plx:string>
							<xsl:value-of select="concat($ClassName,'{0}{{{0}{1}')"/>
							<xsl:for-each select="$NonCollectionProperties">
								<xsl:value-of select="concat(@name,' = ')"/>
								<xsl:if test="not(@isCustomType='true')">
									<xsl:value-of select="'&quot;'"/>
								</xsl:if>
								<xsl:value-of select="concat('{',position()+1,'}')"/>
								<xsl:if test="not(@isCustomType='true')">
									<xsl:value-of select="'&quot;'"/>
								</xsl:if>
								<xsl:if test="not(position()=last())">
									<xsl:value-of select="',{0}{1}'"/>
								</xsl:if>
							</xsl:for-each>
							<xsl:value-of select="'{0}}}'"/>
						</plx:string>
					</plx:passParam>
					<plx:passParam>
						<plx:callStatic type="field" name="NewLine" dataTypeName="Environment"/>
					</plx:passParam>
					<plx:passParam>
						<plx:string>
							<xsl:text>&#x09;</xsl:text>
						</plx:string>
					</plx:passParam>
					<xsl:for-each select="$NonCollectionProperties">
						<plx:passParam>
							<xsl:choose>
								<xsl:when test="@isCustomType='true'">
									<plx:string>TODO: Recursively call ToString for customTypes...</plx:string>
								</xsl:when>
								<xsl:otherwise>
									<plx:callThis accessor="this" type="property" name="{@name}"/>
								</xsl:otherwise>
							</xsl:choose>
						</plx:passParam>
					</xsl:for-each>
				</plx:callStatic>
			</plx:return>
		</plx:function>
	</xsl:template>
	
	<xsl:template name="GenerateModelContextInterfaceMethods">
		<xsl:param name="Model"/>
		<xsl:param name="AllProperties"/>
		<plx:property visibility="public" modifier="abstract" name="IsDeserializing">
			<plx:returns dataTypeName=".boolean"/>
			<plx:get/>
		</plx:property>
		<xsl:call-template name="GenerateModelContextInterfaceLookupMethods">
			<xsl:with-param name="Model" select="$Model"/>
			<xsl:with-param name="AllProperties" select="$AllProperties"/>
		</xsl:call-template>
	</xsl:template>
	<xsl:template name="GenerateModelContextInterfaceLookupMethods">
		<xsl:param name="Model"/>
		<xsl:param name="AllProperties"/>
		<!-- TODO: This will break for oil:roleSequenceUniquenessConstraint elements that contain oil:typeRef elements with more than one oil:conceptType reference by @targetConceptType. -->
		<xsl:for-each select="$Model//oil:roleSequenceUniquenessConstraint">
			<xsl:variable name="uniqueConceptTypeName" select="parent::oil:conceptType/@name"/>
			<plx:function visibility="public" name="Get{$uniqueConceptTypeName}By{@name}">
				<xsl:for-each select="oil:roleSequence/oil:typeRef">
					<plx:param name="{@targetChild}">
						<xsl:variable name="targetProperty" select="$AllProperties[@conceptTypeName=$uniqueConceptTypeName]/prop:Property[@name=current()/@targetChild]"/>
						<xsl:copy-of select="$targetProperty/prop:DataType/@*"/>
						<xsl:copy-of select="$targetProperty/prop:DataType/child::*"/>
					</plx:param>
				</xsl:for-each>
				<plx:returns dataTypeName="{$uniqueConceptTypeName}"/>
			</plx:function>
		</xsl:for-each>
		<xsl:for-each select="$AllProperties/prop:Property[@isUnique='true' and not(@isCustomType='true')]">
			<xsl:variable name="uniqueConceptTypeName" select="parent::prop:Properties/@conceptTypeName"/>
			<!-- TODO: In Get{Thing}By{Name}, {Name} should be oil:singleRoleUniquenessConstraint/@name rather than prop:Property/@name. -->
			<plx:function visibility="public" name="Get{$uniqueConceptTypeName}By{@name}">
				<plx:param name="{@name}">
					<xsl:copy-of select="prop:DataType/@*"/>
					<xsl:copy-of select="prop:DataType/child::*"/>
				</plx:param>
				<plx:returns dataTypeName="{$uniqueConceptTypeName}"/>
			</plx:function>
		</xsl:for-each>
	</xsl:template>
	
	<xsl:template match="oil:conceptType" mode="GenerateModelContextInterfaceObjectMethods">
		<xsl:param name="Model"/>
		<xsl:param name="Properties"/>
		<plx:function visibility="public" modifier="abstract" name="Create{@name}">
			<xsl:call-template name="GenerateMandatoryParameters">
				<xsl:with-param name="Properties" select="$Properties"/>
			</xsl:call-template>
			<plx:returns dataTypeName="{@name}"/>
		</plx:function>
		<plx:property visibility="public" modifier="abstract" name="{@name}Collection">
				<plx:returns dataTypeName="ReadOnlyCollection">
					<plx:passTypeParam dataTypeName="{@name}"/>
				</plx:returns>
				<plx:get/>
			</plx:property>
	</xsl:template>

	<xsl:template name="GenerateMandatoryParameters">
		<xsl:param name="Properties"/>
		<xsl:for-each select="$Properties[@mandatory='alethic']">
			<plx:param name="{@name}">
				<xsl:copy-of select="prop:DataType/@*"/>
				<xsl:copy-of select="prop:DataType/child::*"/>
			</plx:param>
		</xsl:for-each>
	</xsl:template>
	
</xsl:stylesheet>
