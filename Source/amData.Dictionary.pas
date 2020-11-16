unit amData.Dictionary;

////////////////////////////////////////////////////////////////////////////////
//
//      Database Metadata Repository
//
////////////////////////////////////////////////////////////////////////////////

(*
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the License.

  The Original Code is amData.Dictionary

  The Initial Developer of the Original Code is Anders Melander.

  Portions created by the Initial Developer are Copyright (C) 2001
  the Initial Developer. All Rights Reserved.

  Contributor(s):
    -

  Alternatively, the contents of this file may be used under the terms of
  either the GNU General Public License Version 2 or later (the "GPL"), or
  the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
  in which case the provisions of the GPL or the LGPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of either the GPL or the LGPL, and not to allow others to
  use your version of this file under the terms of the MPL, indicate your
  decision by deleting the provisions above and replace them with the notice
  and other provisions required by the GPL or the LGPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the MPL, the GPL or the LGPL.
*)

{$define STREAM_V2_IN}
{$define STREAM_V2_OUT}

// Audit flag validation has been disabled since tables with STOREID in their PK can have 2 PK fields
{_$define DD_VALIDATE_AUDIT}

interface

uses
  Classes,
  DB,
  Generics.Collections,
//  Contnrs,
  Types,
  TypInfo;

type
  TCustomDataDictionary = class;
  TCustomDataDictionaryTable = class;
  TCustomDataDictionaryDomain = class;
  TCustomDataDictionaryField = class;
  TCustomDataDictionaryRelationship = class;
  TCustomDataDictionaryIndex = class;
  TDataDictionaryDomains = class;

  TCharCase = (ccNone, ccUpper, ccLower);

  IObserver = interface
    ['{F9EC8B6D-361C-41BA-B565-58BF92919386}']
    procedure Notification(Item: TObject);
  end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryCollectionItem
//
////////////////////////////////////////////////////////////////////////////////
// Base class for data dictionary collection items.
////////////////////////////////////////////////////////////////////////////////
  TRepositoryState = (rsFixup, rsLoading, rsDestroying);
  TRepositoryStates = set of TRepositoryState;

  TDataDictionaryCollectionItem = class abstract(TCollectionItem, IObserver)
  private
    FObservers: TList<TDataDictionaryCollectionItem>;
    FState: TRepositoryStates;
    FSubscriptions: TList<TDataDictionaryCollectionItem>;
  protected
    function GetRepository: TCustomDataDictionary; virtual;
    function GetState: TRepositoryStates;
    procedure Notify;
    procedure Notification(Item: TObject); virtual;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    procedure AddSubscription(Item: TDataDictionaryCollectionItem);
    procedure RemoveSubscription(Item: TDataDictionaryCollectionItem);
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    procedure BeforeDestruction; override;
    procedure Subscribe(Observer: TDataDictionaryCollectionItem);
    procedure Unsubscribe(Observer: TDataDictionaryCollectionItem);
    procedure SetState(AState: TRepositoryState);
    procedure ClearState(AState: TRepositoryState);
    property Repository: TCustomDataDictionary read GetRepository;
    property State: TRepositoryStates read GetState;
  published
  end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryCollection
//
////////////////////////////////////////////////////////////////////////////////
// Base class for data dictionary collections.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryCollection = class abstract(TOwnedCollection, IObserver)
  protected
    function GetRepository: TCustomDataDictionary; virtual;
    procedure Notification(Item: TObject); virtual;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    constructor Create(AOwner: TPersistent; ItemClass: TCollectionItemClass);
    function ItemByName(const Name: string): TDataDictionaryCollectionItem;
    property Repository: TCustomDataDictionary read GetRepository;
  end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryList
//
////////////////////////////////////////////////////////////////////////////////
// Base class for data dictionary collection item lists.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryList = class abstract(TList<TDataDictionaryCollectionItem>, IObserver)
  private
    // IUnknown
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  protected
    // IObserver
    procedure Notification(Item: TObject); virtual;

    function ItemByName(const Name: string): TDataDictionaryCollectionItem;
  public
  end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryFieldList
//
////////////////////////////////////////////////////////////////////////////////
// List of TCustomDataDictionaryField.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryFieldList = class(TDataDictionaryList)
  private
    function GetField(Index: integer): TCustomDataDictionaryField;
  public
    function Add(AField: TCustomDataDictionaryField): integer;
    function FieldByName(const Name: string): TCustomDataDictionaryField;
    property Fields[Index: integer]: TCustomDataDictionaryField read GetField; default;
  end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryDomainList
//
////////////////////////////////////////////////////////////////////////////////
// List of TCustomDataDictionaryDomain.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryDomainList = class(TDataDictionaryList)
  private
    function GetDomain(Index: integer): TCustomDataDictionaryDomain;
  public
    function Add(ADomain: TCustomDataDictionaryDomain): integer;
    function DomainByName(const Name: string): TCustomDataDictionaryDomain;
    property Domains[Index: integer]: TCustomDataDictionaryDomain read GetDomain; default;
  end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryFieldDef
//
////////////////////////////////////////////////////////////////////////////////
// Base class for field related data dictionary collection items.
// Contains properties common for physical field attributes (fields) and logical
// field attributes (domains).
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryFieldDef = class abstract(TDataDictionaryCollectionItem)
  private
    FSize: Integer;
    FPrecision: Integer;
    FFieldKind: TFieldKind;
    FDataType: TFieldType;
    FPhysical: string;
    FRequired: boolean;
    FDefaultValue: Variant;
    FConstraint: string;
  protected
    function GetQualifiedName: string; virtual; abstract;
    procedure SetRequired(const Value: boolean); virtual;
  public
    constructor Create(AOwner: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    property QualifiedName: string read GetQualifiedName;
    property Required: boolean read FRequired write SetRequired default False;
  published
    property DataType: TFieldType read FDataType write FDataType default ftUnknown;
    property Precision: Integer read FPrecision write FPrecision default 0;
    property Size: Integer read FSize write FSize default 0;
    property FieldKind: TFieldKind read FFieldKind write FFieldKind default fkData;
    property Physical: string read FPhysical write FPhysical;
    property DefaultValue: Variant read FDefaultValue write FDefaultValue;
    property Constraint: string read FConstraint write FConstraint;
  end;

////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionaryDomain
//
////////////////////////////////////////////////////////////////////////////////
// Collection item which represents a database domain (custom type).
// Contains domain properties.
////////////////////////////////////////////////////////////////////////////////
  TCustomDataDictionaryDomain = class(TDataDictionaryFieldDef)
  private
    FDomainName: string;
    FChildren: TDataDictionaryDomainList;
    FReferences: TDataDictionaryFieldList;
    FParent: TCustomDataDictionaryDomain;
    procedure ReadDataParent(Reader: TReader);
    procedure WriteDataParent(Writer: TWriter);
  protected
    procedure DefineProperties(Filer: TFiler); override;
    function GetQualifiedName: string; override;
    procedure SetParent(const Value: TCustomDataDictionaryDomain);
    function GetDisplayName: string; override;
    procedure Notification(Item: TObject); override;
  public
    constructor Create(AOwner: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    property Children: TDataDictionaryDomainList read FChildren;
    property References: TDataDictionaryFieldList read FReferences;
  published
    property DomainName: string read FDomainName write FDomainName;
    property Name: string read FDomainName;
    property Parent: TCustomDataDictionaryDomain read FParent write SetParent stored False;
    property Required;
  end;

  TDataDictionaryDomainClass = class of TCustomDataDictionaryDomain;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryDomains
//
////////////////////////////////////////////////////////////////////////////////
// Collection of TCustomDataDictionaryDomain items.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryDomains = class(TDataDictionaryCollection)
  private
  protected
    function GetDomain(Index: integer): TCustomDataDictionaryDomain;
    procedure SetDomain(Index: integer; const Value: TCustomDataDictionaryDomain);
  public
    constructor Create(AOwner: TPersistent);
    function IndexOf(const DomainName: string): integer;
    function DomainByName(const Name: string): TCustomDataDictionaryDomain;
    function FindDomain(const Name: string): TCustomDataDictionaryDomain;
    property Domains[Index: integer]: TCustomDataDictionaryDomain read GetDomain write SetDomain; default;
  end;

  TDataDictionaryDomainsClass = class of TDataDictionaryDomains;

////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionaryField
//
////////////////////////////////////////////////////////////////////////////////
// Collection item which represents a table field.
// Contains field properties.
////////////////////////////////////////////////////////////////////////////////
  TAutoValue = (avNone, avDefault, avSequence, avUnique);

  TCustomDataDictionaryField = class(TDataDictionaryFieldDef)
  private
    FFieldName: string;
    FDisplayLabel: string;
    FOrigin: string;
    FPrimaryKey: boolean;
    FForeignKey: TCustomDataDictionaryField;
    FParamType: TParamType;
    FReferences: TDataDictionaryFieldList;
    FDomain: TCustomDataDictionaryDomain;
    FHidden: boolean;
    FUnique: boolean;
    FAutoGenerateValue: TAutoValue;
    FDisplayWidth: Integer;
    FCharCase: TCharCase;
    FReadOnly: boolean;
    procedure ReadDataFK(Reader: TReader);
    procedure WriteDataFK(Writer: TWriter);
    procedure ReadDataDomain(Reader: TReader);
    procedure WriteDataDomain(Writer: TWriter);
  protected
    procedure DefineProperties(Filer: TFiler); override;
    procedure SetParamType(const Value: TParamType);
    procedure SetForeignKey(const Value: TCustomDataDictionaryField); virtual;
    procedure SetPrimaryKey(const Value: boolean); virtual;
    function GetQualifiedName: string; override;
    procedure SetDomain(const Value: TCustomDataDictionaryDomain);
    function GetTable: TCustomDataDictionaryTable;
    function GetDisplayName: string; override;
    function GetDisplayLabel: string;
    function IsDisplayLabelStored: Boolean;
    function GetOrigin: string;
    function IsOriginStored: Boolean;
    procedure SetHidden(const Value: boolean); virtual;
    procedure SetUnique(const Value: boolean); virtual;
    procedure SetRequired(const Value: boolean); override;
    procedure SetFieldName(const Value: string); virtual;
    procedure Notification(Item: TObject); override;
  public
    constructor Create(AOwner: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    property References: TDataDictionaryFieldList read FReferences;
    property Table: TCustomDataDictionaryTable read GetTable;
    // TODO: ParentRelationship
//    property ParentRelationship: TDataDictionaryRelationshipField read GetParentRelationship;
    // TODO: ChildRelationships
//    property ChildRelationships: TRepositoryRelationshipFieldList read FChildRelationships;
  published
    property FieldName: string read FFieldName write SetFieldName;
    property Name: string read FFieldName;
    property DisplayLabel: string read GetDisplayLabel write FDisplayLabel
      stored IsDisplayLabelStored;
    property Origin: string read GetOrigin write FOrigin stored IsOriginStored;
    property Domain: TCustomDataDictionaryDomain read FDomain write SetDomain stored False;
    property PrimaryKey: boolean read FPrimaryKey write SetPrimaryKey default False;
    property ForeignKey: TCustomDataDictionaryField read FForeignKey write SetForeignKey stored False;
    property ParamType: TParamType read FParamType write SetParamType default ptOutput;
    property Unique: boolean read FUnique write SetUnique default False;
    property Hidden: boolean read FHidden write SetHidden default False;
    property AutoGenerateValue: TAutoValue read FAutoGenerateValue write FAutoGenerateValue default avNone;
    property DisplayWidth: Integer read FDisplayWidth write FDisplayWidth default 0;
    property CharCase: TCharCase read FCharCase write FCharCase default ccNone;
    property ReadOnly: boolean read FReadOnly write FReadOnly default False;
    property Required;
  end;

  TDataDictionaryFieldClass = class of TCustomDataDictionaryField;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryFields
//
////////////////////////////////////////////////////////////////////////////////
// Collection of TCustomDataDictionaryField items.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryFields = class(TDataDictionaryCollection)
  private
    FTable: TCustomDataDictionaryTable;
  protected
    function GetField(Index: integer): TCustomDataDictionaryField;
    procedure SetField(Index: integer; const Value: TCustomDataDictionaryField);
  public
    constructor Create(AOwner: TPersistent);
    function IndexOf(const FieldName: string): integer;
    function FieldByName(const Name: string): TCustomDataDictionaryField;
    function FindField(const Name: string): TCustomDataDictionaryField;
    property Table: TCustomDataDictionaryTable read FTable write FTable;
    property Fields[Index: integer]: TCustomDataDictionaryField read GetField write SetField; default;
  end;

  TTableType = (ttPhysical, ttView, ttStoredProcedure, ttCustom);

////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionaryIndex
//
////////////////////////////////////////////////////////////////////////////////
// Collection item which represents a table index.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryIndexField = class(TDataDictionaryCollectionItem)
  private
    FField: TCustomDataDictionaryField;
    procedure ReadDataField(Reader: TReader);
    procedure WriteDataField(Writer: TWriter);
  protected
    procedure DefineProperties(Filer: TFiler); override;
    function GetDisplayName: string; override;
    procedure SetField(const Value: TCustomDataDictionaryField);
    function GetIndex: TCustomDataDictionaryIndex;
    procedure Notification(Item: TObject); override;
  public
    destructor Destroy; override;
    property Index: TCustomDataDictionaryIndex read GetIndex;
  published
    property Field: TCustomDataDictionaryField read FField write SetField stored False;
  end;

  TDataDictionaryIndexFields = class(TDataDictionaryCollection)
  private
    FIndex: TCustomDataDictionaryIndex;
  protected
    function GetField(Index: integer): TDataDictionaryIndexField;
    procedure SetField(Index: integer; const Value: TDataDictionaryIndexField);
  public
    constructor Create(AOwner: TPersistent);
    function IndexOf(const Name: string): integer;
    function FieldByName(const Name: string): TDataDictionaryIndexField;
    function FindField(const Name: string): TDataDictionaryIndexField;
    property Index: TCustomDataDictionaryIndex read FIndex write FIndex;
    property Fields[Index: integer]: TDataDictionaryIndexField read GetField write SetField; default;
  end;

  (*
  ** Index types:
  ** - itPrimaryKey             Primary key index. Unique.
  ** - itForeignKey             Foreign key index.
  ** - itAlternateKey           Unique index.
  ** - itInversionEntry         Non-unique index.
  *)
  TIndexType = (itPrimaryKey, itForeignKey, itAlternateKey, itInversionEntry);

  TSortOrder = (soAscending, soDesceding);

  TCustomDataDictionaryIndex = class(TDataDictionaryCollectionItem)
  private
    FName: string;
    FIndexType: TIndexType;
    FFields: TDataDictionaryIndexFields;
    FUnique: boolean;
    FSortOrder: TSortOrder;
    procedure SetIndexType(const Value: TIndexType);
    procedure SetFields(const Value: TDataDictionaryIndexFields);
    procedure SetUnique(const Value: boolean);
  protected
    function GetTable: TCustomDataDictionaryTable;
    function GetDisplayName: string; override;
  public
    constructor Create(AOwner: TCollection); override;
    destructor Destroy; override;
    property Table: TCustomDataDictionaryTable read GetTable;
  published
    property Name: string read FName write FName;
    property IndexType: TIndexType read FIndexType write SetIndexType default itInversionEntry;
    property Fields: TDataDictionaryIndexFields read FFields write SetFields;
    property Unique: boolean read FUnique write SetUnique default False;
    property SortOrder: TSortOrder read FSortOrder write FSortOrder default soAscending;
  end;

  TDataDictionaryIndexClass = class of TCustomDataDictionaryIndex;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryIndices
//
////////////////////////////////////////////////////////////////////////////////
// Collection of table indexes.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryIndices = class(TDataDictionaryCollection)
  private
    FTable: TCustomDataDictionaryTable;
  protected
    function GetIndex(Index: integer): TCustomDataDictionaryIndex;
    procedure SetIndex(Index: integer; const Value: TCustomDataDictionaryIndex);
  public
    constructor Create(AOwner: TPersistent);
    function IndexOf(const Name: string): integer;
    function IndexByName(const Name: string): TCustomDataDictionaryIndex;
    function FindIndex(const Name: string): TCustomDataDictionaryIndex;
    property Table: TCustomDataDictionaryTable read FTable write FTable;
    property Indices[Index: integer]: TCustomDataDictionaryIndex read GetIndex write SetIndex; default;
  end;

////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionaryRelationship
//
////////////////////////////////////////////////////////////////////////////////
// Collection item which represents a parent/child relationship between two
// tables.
////////////////////////////////////////////////////////////////////////////////
  TReferentialIntegrityAction = (riNone, riRestrict, riSetNull, riSetDefault, riCascade);
  TReferentialIntegrityActions = set of TReferentialIntegrityAction;

  TReferentialIntegrityRule = (raDelete, raInsert, raUpdate);

  TReferentialIntegrityRules = class(TPersistent)
  private
    FValues: array[TReferentialIntegrityRule] of TReferentialIntegrityAction;
    FMask: TReferentialIntegrityActions;
  protected
    procedure SetMask(const Value: TReferentialIntegrityActions);
    function GetValue(Index: TReferentialIntegrityRule): TReferentialIntegrityAction;
    procedure SetValue(Index: TReferentialIntegrityRule; const Value: TReferentialIntegrityAction);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    property Mask: TReferentialIntegrityActions read FMask write SetMask;
    property Rules[Index: TReferentialIntegrityRule]: TReferentialIntegrityAction read GetValue write SetValue; default;
  published
    property Delete: TReferentialIntegrityAction index raDelete read GetValue write SetValue default riNone;
    property Insert: TReferentialIntegrityAction index raInsert read GetValue write SetValue default riNone;
    property Update: TReferentialIntegrityAction index raUpdate read GetValue write SetValue default riNone;
  end;

  TReferentialIntegrityMember = (rmChild, rmParent);

  TReferentialIntegrity = class(TPersistent)
  private
    FValues: array[TReferentialIntegrityMember] of TReferentialIntegrityRules;
  protected
    function GetMask: TReferentialIntegrityActions;
    procedure SetMask(const Value: TReferentialIntegrityActions);
    procedure SetValue(Index: TReferentialIntegrityMember; Value: TReferentialIntegrityRules);
    function GetValue(Index: TReferentialIntegrityMember): TReferentialIntegrityRules;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    property Mask: TReferentialIntegrityActions read GetMask write SetMask;
    property Members[Index: TReferentialIntegrityMember]: TReferentialIntegrityRules read GetValue write SetValue; default;
  published
    property Child: TReferentialIntegrityRules index rmChild read GetValue write SetValue stored False;
    property Parent: TReferentialIntegrityRules index rmParent read GetValue write SetValue stored False;
  end;

  TCardinality = (caZeroPlus, caOnePlus, caZeroOne, caExactly);

  TDataDictionaryRelationshipField = class(TDataDictionaryCollectionItem)
  private
    FChild: TCustomDataDictionaryField;
    FParent: TCustomDataDictionaryField;
    procedure ReadDataParentField(Reader: TReader);
    procedure WriteDataParentField(Writer: TWriter);
    procedure ReadDataChildField(Reader: TReader);
    procedure WriteDataChildField(Writer: TWriter);
  protected
    procedure DefineProperties(Filer: TFiler); override;
    procedure SetChild(const Value: TCustomDataDictionaryField);
    procedure SetParent(const Value: TCustomDataDictionaryField);
    function GetDisplayName: string; override;
    function GetRelationship: TCustomDataDictionaryRelationship;
    procedure Notification(Item: TObject); override;
  public
    destructor Destroy; override;
    property Relationship: TCustomDataDictionaryRelationship read GetRelationship;
  published
    property ParentField: TCustomDataDictionaryField read FParent write SetParent stored False;
    property ChildField: TCustomDataDictionaryField read FChild write SetChild stored False;
  end;

  TDataDictionaryRelationshipFields = class(TDataDictionaryCollection)
  private
    FRelationship: TCustomDataDictionaryRelationship;
  protected
    function GetField(Index: integer): TDataDictionaryRelationshipField;
    procedure SetField(Index: integer; const Value: TDataDictionaryRelationshipField);
  public
    constructor Create(AOwner: TPersistent);
    function IndexOfParent(const Name: string): integer;
    function IndexOfChild(const Name: string): integer;
    function FieldByParentName(const Name: string): TDataDictionaryRelationshipField;
    function FieldByChildName(const Name: string): TDataDictionaryRelationshipField;
    function FindParentField(const Name: string): TDataDictionaryRelationshipField;
    function FindChildField(const Name: string): TDataDictionaryRelationshipField;
    property Relationship: TCustomDataDictionaryRelationship read FRelationship write FRelationship;
    property Fields[Index: integer]: TDataDictionaryRelationshipField read GetField write SetField; default;
  end;

  TCustomDataDictionaryRelationship = class(TDataDictionaryCollectionItem)
  private
    FFields: TDataDictionaryRelationshipFields;
    FReferentialIntegrity: TReferentialIntegrity;
    FIdentifying: boolean;
    FRequired: boolean;
    FCardinalityCount: integer;
    FCardinality: TCardinality;
    FParentIndex: TCustomDataDictionaryIndex;
    FChildIndex: TCustomDataDictionaryIndex;
    FChildTable: TCustomDataDictionaryTable;
    FName: string;
    procedure ReadDataChildTable(Reader: TReader);
    procedure WriteDataChildTable(Writer: TWriter);
    procedure ReadDataParentIndex(Reader: TReader);
    procedure WriteDataParentIndex(Writer: TWriter);
    procedure ReadDataChildIndex(Reader: TReader);
    procedure WriteDataChildIndex(Writer: TWriter);
  protected
    procedure DefineProperties(Filer: TFiler); override;
    function GetDisplayName: string; override;
    procedure SetCardinality(const Value: TCardinality);
    procedure SetCardinalityCount(const Value: integer);
    procedure SetChildTable(const Value: TCustomDataDictionaryTable);
    procedure SetIdentifying(const Value: boolean);
    procedure SetParentIndex(const Value: TCustomDataDictionaryIndex);
    procedure SetChildIndex(const Value: TCustomDataDictionaryIndex);
    function GetParentTable: TCustomDataDictionaryTable;
    procedure SetReferentialIntegrity(const Value: TReferentialIntegrity);
    procedure SetRequired(const Value: boolean);
    procedure SetFields(const Value: TDataDictionaryRelationshipFields);
    procedure UpdateMask;
    procedure ImportFields;
    procedure Notification(Item: TObject); override;
  public
    constructor Create(AOwner: TCollection); override;
    destructor Destroy; override;
    property ParentTable: TCustomDataDictionaryTable read GetParentTable;
  published
    property Name: string read FName write FName;
    property ChildTable: TCustomDataDictionaryTable read FChildTable write SetChildTable stored False;
    property Fields: TDataDictionaryRelationshipFields read FFields write SetFields;

    property ParentIndex: TCustomDataDictionaryIndex read FParentIndex write SetParentIndex stored False;
    property ChildIndex: TCustomDataDictionaryIndex read FChildIndex write SetChildIndex stored False;
    // TODO : Who should control the attributes of the fields/relation? The fields or the relation? In ERwin the relation controls the fields.
    property Identifying: boolean read FIdentifying write SetIdentifying default False; // RO, value based on FK attributes?
    property Required: boolean read FRequired write SetRequired; // RO, value based on FK attributes?

    property Cardinality: TCardinality read FCardinality write SetCardinality default caZeroPlus;
    property CardinalityCount: integer read FCardinalityCount write SetCardinalityCount default 0;
    property ReferentialIntegrity: TReferentialIntegrity read FReferentialIntegrity write SetReferentialIntegrity;
  end;

  TDataDictionaryRelationshipClass = class of TCustomDataDictionaryRelationship;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryRelationships
//
////////////////////////////////////////////////////////////////////////////////
// Collection of TCustomDataDictionaryRelationship items.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryRelationships = class(TDataDictionaryCollection)
  private
    FTable: TCustomDataDictionaryTable;
  protected
    function GetRelationship(Index: integer): TCustomDataDictionaryRelationship;
    procedure SetRelationship(Index: integer; const Value: TCustomDataDictionaryRelationship);
  public
    constructor Create(AOwner: TPersistent);
    property Table: TCustomDataDictionaryTable read FTable write FTable;
    function IndexOf(const Name: string): integer;
    function RelationshipByName(const Name: string): TCustomDataDictionaryRelationship;
    function FindRelationship(const Name: string): TCustomDataDictionaryRelationship;
    property Relationships[Index: integer]: TCustomDataDictionaryRelationship read GetRelationship write SetRelationship; default;
  end;


////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionaryTable
//
////////////////////////////////////////////////////////////////////////////////
// Collection item which represents a database table.
// Contains table properties and a collection of table fields.
////////////////////////////////////////////////////////////////////////////////
  TCustomDataDictionaryTable = class(TDataDictionaryCollectionItem)
  private
    FTableName: string;
    FObjectName: string;
    FFields: TDataDictionaryFields;
    FTableType: TTableType;
    FSchema: TStrings;
    FDisplayLabel: string;
    FRelationships: TDataDictionaryRelationships;
    FIndices: TDataDictionaryIndices;
  protected
    procedure SetFields(const Value: TDataDictionaryFields);
    procedure SetRelationships(const Value: TDataDictionaryRelationships);
    procedure SetIndices(const Value: TDataDictionaryIndices);
    function GetDisplayName: string; override;
    procedure SetSchema(const Value: TStrings);
    function GetDisplayLabel: string;
    function GetObjectName: string;
    function IsDisplayLabelStored: Boolean;
    function IsObjectNameStored: boolean;
    function IsIndicesStored: Boolean;
    function IsRelationshipsStored: Boolean;
    function GetIsDetailTable: boolean;
    function GetIsMasterTable: boolean;
  public
    constructor Create(AOwner: TCollection); override;
    destructor Destroy; override;
    property IsMasterTable: boolean read GetIsMasterTable;
    property IsDetailTable: boolean read GetIsDetailTable;
  published
    property TableName: string read FTableName write FTableName;
    property ObjectName: string read GetObjectName write FObjectName stored IsObjectNameStored;
    property Fields: TDataDictionaryFields read FFields write SetFields;
    property TableType: TTableType read FTableType write FTableType default ttPhysical;
    property Schema: TStrings read FSchema write SetSchema;
    property DisplayLabel: string read GetDisplayLabel write FDisplayLabel stored IsDisplayLabelStored;
    property Relationships: TDataDictionaryRelationships read FRelationships write SetRelationships stored IsRelationshipsStored;
    property Indices: TDataDictionaryIndices read FIndices write SetIndices stored IsIndicesStored;
  end;

  TDataDictionaryTableClass = class of TCustomDataDictionaryTable;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryTables
//
////////////////////////////////////////////////////////////////////////////////
// Collection of TCustomDataDictionaryTable items.
////////////////////////////////////////////////////////////////////////////////
  TDataDictionaryTables = class(TDataDictionaryCollection)
  private
  protected
    function GetTable(Index: integer): TCustomDataDictionaryTable;
    procedure SetTable(Index: integer; const Value: TCustomDataDictionaryTable);
  public
    constructor Create(AOwner: TPersistent);
    function IndexOf(const TableName: string): integer;
    function TableByName(const Name: string): TCustomDataDictionaryTable;
    function FindTable(const Name: string): TCustomDataDictionaryTable;
    function IndexOfObject(const ObjectName: string): integer;
    function TableByObjectName(const Name: string): TCustomDataDictionaryTable;
    function FindObject(const Name: string): TCustomDataDictionaryTable;
    property Tables[Index: integer]: TCustomDataDictionaryTable read GetTable write SetTable; default;
  end;

  TDataDictionaryTablesClass = class of TDataDictionaryTables;

////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionary
//
////////////////////////////////////////////////////////////////////////////////
// Data dictionary component.
// Contains database properties and collections of database tables and domains.
////////////////////////////////////////////////////////////////////////////////
  TCustomDataDictionary = class(TComponent)
  strict private type
    TPropFixup = class
    public type
    {$ifndef STREAM_V2_IN}
      TFixupKind = (fkGeneric, fkField, fkDomain);
    {$endif}
    strict private
  {$ifndef STREAM_V2_IN}
      FKind: TFixupKind;
      FInstance: TPersistent;
      FTableName: string;
      FFieldName: string;
  {$endif}
      FPath: string;
      FPropInfo: PPropInfo;
      FCollectionItem: TDataDictionaryCollectionItem;
    public
  {$ifndef STREAM_V2_IN}
      constructor Create(AInstance: TPersistent; APropInfo: PPropInfo; const ATableName, AFieldName: string); overload;
  {$endif}
      constructor Create(ACollectionItem: TDataDictionaryCollectionItem; APropInfo: PPropInfo; const APath: string); overload;
  {$ifndef STREAM_V2_IN}
      property Kind: TFixupKind read FKind;
      property Instance: TPersistent read FInstance;
      property TableName: string read FTableName;
      property FieldName: string read FFieldName;
  {$endif}
      property PropInfo: PPropInfo read FPropInfo;
      property CollectionItem: TDataDictionaryCollectionItem read FCollectionItem;
      property Path: string read FPath;
    end;
  private
    FTables: TDataDictionaryTables;
    FDomains: TDataDictionaryDomains;
    FFixups: TObjectList<TPropFixup>;
    FState: TRepositoryStates;
    function IsTablesStored: Boolean;
    function IsDomainsStored: Boolean;
  protected
    procedure SetTables(const Value: TDataDictionaryTables);
    procedure SetDomains(const Value: TDataDictionaryDomains);
    procedure AddFixup(Instance: TDataDictionaryCollectionItem; PropInfo: PPropInfo; const Value: string);
{$ifndef STREAM_V2_IN}
    procedure AddFieldFixup(Instance: TPersistent; PropInfo: PPropInfo;
      const TableName, FieldName: string);
    procedure AddDomainFixup(Instance: TPersistent; PropInfo: PPropInfo;
      const FieldName: string);
{$endif}
    procedure Fixup;
    procedure Loaded; override;
    procedure ReadState(Reader: TReader); override;
    function GetDomainClass: TDataDictionaryDomainClass; virtual;
    function GetTableClass: TDataDictionaryTableClass; virtual;
    function GetFieldClass: TDataDictionaryFieldClass; virtual;
    function GetRelationshipClass: TDataDictionaryRelationshipClass; virtual;
    function GetIndexClass:TDataDictionaryIndexClass; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadFromStream(Stream: TStream); virtual;
    procedure SaveToStream(Stream: TStream); virtual;
    procedure SaveToFile(const FileName: string); virtual;
    procedure LoadFromFile(const FileName: string); virtual;
    property State: TRepositoryStates read FState write FState stored False;
  published
    property Domains: TDataDictionaryDomains read FDomains write SetDomains stored IsDomainsStored;
    property Tables: TDataDictionaryTables read FTables write SetTables stored IsTablesStored;
  end;

////////////////////////////////////////////////////////////////////////////////
//
//	Application specific data dictionary classes
//
////////////////////////////////////////////////////////////////////////////////
// TODO : This should be moved to a separate unit
////////////////////////////////////////////////////////////////////////////////
  TUpdateKinds = set of TUpdateKind;

  TDataDictionaryDomain = class(TCustomDataDictionaryDomain)
  end;

  TDataDictionaryTable = class;

  TDataDictionaryFieldOption = (foExport, foPropagateChangeLog,
    foReplicateInvariantKey, foReplicateFromParent, foReplicate);
  TDataDictionaryFieldOptions = set of TDataDictionaryFieldOption;

  TDataDictionaryField = class(TCustomDataDictionaryField)
  private
    FAuditMask: TUpdateKinds;
    FOptions: TDataDictionaryFieldOptions;
    FCustom: boolean;
    FAuditTaskMask: TUpdateKinds;
  protected
    function GetTable: TDataDictionaryTable;
    procedure SetPropagateChangeLog(const Value: boolean); virtual;
    procedure SetForeignKey(const Value: TCustomDataDictionaryField); override;
    procedure SetPrimaryKey(const Value: boolean); override;
    procedure SetFieldName(const Value: string); override;
    procedure SetUnique(const Value: boolean); override;
    procedure SetOptions(Value: TDataDictionaryFieldOptions);
    procedure SetAuditMask(const Value: TUpdateKinds);
    procedure SetAuditTaskMask(const Value: TUpdateKinds);
  public
    constructor Create(AOwner: TCollection); override;
    function CanExport: boolean;
    function CanReplicate: boolean;
    property Table: TDataDictionaryTable read GetTable;
  published
    property Options: TDataDictionaryFieldOptions read FOptions write SetOptions default [foExport, foReplicate];
    property PropagateChangeLog: boolean write SetPropagateChangeLog default False;
    property AuditMask: TUpdateKinds read FAuditMask write SetAuditMask default [];
    property AuditTaskMask: TUpdateKinds read FAuditTaskMask write SetAuditTaskMask default [];
    property Custom: boolean read FCustom write FCustom default False;
  end;

  TDataDictionaryTableOption = (toExport, toSyncSource, toSyncTargets, toAudit, toAutoLock,
    toReplicate, toReplicatable);
  TDataDictionaryTableOptions = set of TDataDictionaryTableOption;

  TDataDictionaryTable = class(TCustomDataDictionaryTable)
  private
    FAuditMask: TUpdateKinds;
    FOptions: TDataDictionaryTableOptions;
    FCustom: boolean;
  protected
    procedure SetOptions(Value: TDataDictionaryTableOptions);
    procedure SetReplicate(const Value: boolean);
  public
    constructor Create(AOwner: TCollection); override;
    function CanExport: boolean;
  published
    property Options: TDataDictionaryTableOptions read FOptions write SetOptions default [toExport, toReplicatable];
    property AuditMask: TUpdateKinds read FAuditMask write FAuditMask default [];
    property Custom: boolean read FCustom write FCustom default False;
    property Replicate: boolean write SetReplicate stored False;
  end;

  TDataDictionary = class(TCustomDataDictionary)
  protected
    function GetDomainClass: TDataDictionaryDomainClass; override;
    function GetTableClass: TDataDictionaryTableClass; override;
    function GetFieldClass: TDataDictionaryFieldClass; override;
  public
  end;


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

implementation

uses
  SysUtils,
//  DBTables,
  UITypes,
  Dialogs,
  Controls,
  Windows;

function FindRepository(Item: TPersistent): TCustomDataDictionary;
begin
  ASSERT(Item <> nil);
  if (Item is TDataDictionaryCollectionItem) then
    Result := TDataDictionaryCollectionItem(Item).Repository
  else
  if (Item is TDataDictionaryCollection) then
    Result := TDataDictionaryCollection(Item).Repository
  else
  if (Item is TCustomDataDictionary) then
    Result := TCustomDataDictionary(Item)
  else
    raise Exception.CreateFmt('Unable to find repository from %s (%s)', [Item.GetNamePath, Item.ClassName]);
end;

////////////////////////////////////////////////////////////////////////////////
//
//      TPropFixup
//
////////////////////////////////////////////////////////////////////////////////
// Utility class for use in load-time linkage fixup.
////////////////////////////////////////////////////////////////////////////////
{$ifndef STREAM_V2_IN}
constructor TCustomDataDictionary.TPropFixup.Create(AInstance: TPersistent; APropInfo: PPropInfo; const ATableName, AFieldName: string);
begin
  inherited Create;
  FInstance := AInstance;
  FPropInfo := APropInfo;
  FTableName := ATableName;
  FFieldName := AFieldName;
  if (FTableName <> '') then
    FKind := fkField
  else
    FKind := fkDomain;
end;
{$endif}

constructor TCustomDataDictionary.TPropFixup.Create(ACollectionItem: TDataDictionaryCollectionItem; APropInfo: PPropInfo; const APath: string);
begin
  inherited Create;
  FPropInfo := APropInfo;
{$ifndef STREAM_V2_IN}
  FKind := fkGeneric;
{$endif}
  FCollectionItem := ACollectionItem;
  FPath := APath;
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryCollectionItem
//
////////////////////////////////////////////////////////////////////////////////
procedure TDataDictionaryCollectionItem.AddSubscription(Item: TDataDictionaryCollectionItem);
begin
  FSubscriptions.Add(Item);
end;

procedure TDataDictionaryCollectionItem.BeforeDestruction;
begin
  FState := [rsDestroying];
  Notify;
  inherited BeforeDestruction;
end;

procedure TDataDictionaryCollectionItem.ClearState(AState: TRepositoryState);
begin
  Exclude(FState, AState);
end;

constructor TDataDictionaryCollectionItem.Create(Collection: TCollection);
begin
  ASSERT((Collection = nil) or (Collection.InheritsFrom(TDataDictionaryCollection)));
  inherited Create(Collection);
  FObservers := TList<TDataDictionaryCollectionItem>.Create;
  FSubscriptions := TList<TDataDictionaryCollectionItem>.Create;
end;

destructor TDataDictionaryCollectionItem.Destroy;
begin
  ASSERT(FObservers.Count = 0);
  ASSERT(FSubscriptions.Count = 0,
    Format('%s(%s) has %d outstanding subscriptions', [ClassName, DisplayName, FSubscriptions]));
  FreeAndNil(FObservers);
  FreeAndNil(FSubscriptions);
  inherited Destroy;
end;

function TDataDictionaryCollectionItem.GetRepository: TCustomDataDictionary;
begin
  if (Collection <> nil) then
    Result := TDataDictionaryCollection(Collection).Repository
  else
    Result := nil;
end;

function TDataDictionaryCollectionItem.GetState: TRepositoryStates;
begin
  Result := FState;
  if (Repository <> nil) then
    Result := Result+Repository.State;
end;

procedure TDataDictionaryCollectionItem.Notification(Item: TObject);
begin
//
end;

procedure TDataDictionaryCollectionItem.Notify;
var
  Observer: IObserver;
  OldCount: integer;
begin
  while (FObservers.Count > 0) do
  begin
    OldCount := FObservers.Count;
    FObservers[0].GetInterface(IObserver, Observer);
    if (Observer <> nil) then
    begin
      Observer.Notification(Self);
      ASSERT(OldCount > FObservers.Count, 'Observer failed to perform unsubscription');
    end else
      FObservers.Delete(0);
  end;
end;

function TDataDictionaryCollectionItem.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
  if GetInterface(IID, Obj) then Result := 0 else Result := HResult($80004002);
end;

procedure TDataDictionaryCollectionItem.RemoveSubscription(Item: TDataDictionaryCollectionItem);
begin
  ASSERT(FSubscriptions.IndexOf(Item) <> -1,
    Format('Unknown subscription in %s(%s): %s(%s)', [ClassName, DisplayName, Item.ClassName, Item.DisplayName]));
  FSubscriptions.Remove(Item);
end;

procedure TDataDictionaryCollectionItem.SetState(AState: TRepositoryState);
begin
  Include(FState, AState);
end;

procedure TDataDictionaryCollectionItem.Subscribe(Observer: TDataDictionaryCollectionItem);
begin
  Observer.AddSubscription(Self);
  FObservers.Add(Observer);
end;

procedure TDataDictionaryCollectionItem.Unsubscribe(Observer: TDataDictionaryCollectionItem);
begin
  ASSERT(FObservers.IndexOf(Observer) <> -1,
    Format('Unknown subscriber in %s(%s): %s(%s)', [ClassName, DisplayName, Observer.ClassName, Observer.DisplayName]));
  FObservers.Remove(Observer);
  Observer.RemoveSubscription(Self);
end;

function TDataDictionaryCollectionItem._AddRef: Integer;
begin
  Result := -1;
end;

function TDataDictionaryCollectionItem._Release: Integer;
begin
  Result := -1;
end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryCollection
//
////////////////////////////////////////////////////////////////////////////////
constructor TDataDictionaryCollection.Create(AOwner: TPersistent;
  ItemClass: TCollectionItemClass);
begin
  ASSERT(ItemClass.InheritsFrom(TDataDictionaryCollectionItem));
  inherited Create(AOwner, ItemClass);
end;

function TDataDictionaryCollection.GetRepository: TCustomDataDictionary;
begin
  Result := FindRepository(GetOwner);
end;

function TDataDictionaryCollection.ItemByName(const Name: string): TDataDictionaryCollectionItem;
var
  i: integer;
begin
  for i := 0 to Count-1 do
    if (Items[i].DisplayName = Name) then
    begin
      Result := TDataDictionaryCollectionItem(Items[i]);
      exit;
    end;
  Result := nil;
end;

procedure TDataDictionaryCollection.Notification(Item: TObject);
begin
//
end;

function TDataDictionaryCollection.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
  if GetInterface(IID, Obj) then Result := 0 else Result := HResult($80004002);
end;

function TDataDictionaryCollection._AddRef: Integer;
begin
  Result := -1;
end;

function TDataDictionaryCollection._Release: Integer;
begin
  Result := -1;
end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryList
//
////////////////////////////////////////////////////////////////////////////////
function TDataDictionaryList.ItemByName(const Name: string): TDataDictionaryCollectionItem;
var
  i: integer;
begin
  for i := 0 to Count-1 do
    if (AnsiSameText(Name, Items[i].DisplayName)) then
    begin
      Result := Items[i];
      exit;
    end;
  Result := nil;
end;

procedure TDataDictionaryList.Notification(Item: TObject);
begin
  if (Item is TDataDictionaryCollectionItem) then
    Remove(TDataDictionaryCollectionItem(Item));
end;

function TDataDictionaryList.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then Result := 0 else Result := HResult($80004002);
end;

function TDataDictionaryList._AddRef: Integer;
begin
  Result := -1;
end;

function TDataDictionaryList._Release: Integer;
begin
  Result := -1;
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionary
//
////////////////////////////////////////////////////////////////////////////////
constructor TCustomDataDictionary.Create(AOwner: TComponent);
begin
  inherited Create(Aowner);
  FTables := TDataDictionaryTables.Create(Self);
  FDomains := TDataDictionaryDomains.Create(Self);
end;

destructor TCustomDataDictionary.Destroy;
begin
  Clear;
  FreeAndNil(FTables);
  FreeAndNil(FDomains);
  FreeAndNil(FFixUps);
  inherited Destroy;
end;

procedure TCustomDataDictionary.Clear;
begin
  FTables.Clear;
  FDomains.Clear;
end;

procedure TCustomDataDictionary.SetTables(const Value: TDataDictionaryTables);
begin
  FTables.Assign(Value);
end;

function TCustomDataDictionary.IsTablesStored: Boolean;
begin
  Result := (FTables.Count > 0);
end;

procedure TCustomDataDictionary.SaveToStream(Stream: TStream);
var
  Writer: TWriter;
begin
  Writer := TWriter.Create(Stream, 1024);
  try
    Writer.WriteCollection(FDomains);
    Writer.WriteCollection(FTables);
  finally
    Writer.Free;
  end;
end;

procedure TCustomDataDictionary.LoadFromStream(Stream: TStream);
var
  Reader: TReader;
begin
  Clear;
  Reader := TReader.Create(Stream, 1024);
  try
    Reader.ReadValue;

    Include(FState, rsLoading);
    try
      Reader.ReadCollection(FDomains);
      Reader.ReadCollection(FTables);

      // Once everything has been loaded we fixup any properties which could not be
      // resolved during load.
      Fixup;
    finally
      Exclude(FState, rsLoading);
    end;
  finally
    Reader.Free;
  end;
end;

procedure TCustomDataDictionary.LoadFromFile(const FileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TCustomDataDictionary.SaveToFile(const FileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TCustomDataDictionary.SetDomains(const Value: TDataDictionaryDomains);
begin
  FDomains.Assign(Value);
end;

function TCustomDataDictionary.IsDomainsStored: Boolean;
begin
  Result := (FDomains.Count > 0);
end;

procedure TCustomDataDictionary.AddFixup(Instance: TDataDictionaryCollectionItem; PropInfo: PPropInfo; const Value: string);
begin
  if (FFixups = nil) then
    FFixups := TObjectList<TPropFixup>.Create(True);
  FFixups.Add(TPropFixup.Create(Instance, PropInfo, Value));
end;

{$ifndef STREAM_V2_IN}
procedure TCustomDataDictionary.AddFieldFixup(Instance: TPersistent; PropInfo: PPropInfo; const TableName, FieldName: string);
begin
  if (FFixups = nil) then
    FFixups := TObjectList<TPropFixup>.Create(True);
  FFixups.Add(TPropFixup.Create(Instance, PropInfo, TableName, FieldName));
end;

procedure TCustomDataDictionary.AddDomainFixup(Instance: TPersistent; PropInfo: PPropInfo; const FieldName: string);
begin
  AddFieldFixup(Instance, PropInfo, '', FieldName);
end;
{$endif}

procedure TCustomDataDictionary.Fixup;

  function Blah(Parent: TPersistent; Path: string): TObject;
  var
    i, j: integer;
    NewParent: TPersistent;
    Prop: PPropInfo;
  begin
    if (Path = '') then
    begin
      Result := Parent;
      exit;
    end;
    // First element in path is parent - remove it.
    i := 1;
    while (not(Path[i] in ['.', '['])) do
    begin
      inc(i);
      ASSERT(i <= Length(Path));
    end;

    // First element is either terminated with an object delimitor (.) or an index brace ([).
    if (Path[i] = '[') then
    begin
      // Object must be a collection
      ASSERT(Parent is TCollection, Format('%s is a %s', [Parent.GetNamePath, Parent.ClassName]));
      inc(i);
      j := i;
      // Get index into collection to find collection item
      while (Path[j] in ['0'..'9']) do
        inc(j);
//      ShowMessage(Format('Path: %s, Collection[%d]', [Path, StrToInt(Copy(Path, i, j-i))]));
      NewParent := TCollection(Parent).Items[StrToInt(Copy(Path, i, j-i))];
      Result := Blah(NewParent, Copy(Path, j+1, Length(Path)));
    end else
    begin
      // Move on to next element in path.
      inc(i);
      j := i;
      // Find name of property
      while (j <= Length(Path)) and (not(Path[j] in ['.', '['])) do
        inc(j);
//      ShowMessage(Format('Path: %s, Property(%s)', [Path, Copy(Path, i, j-i)]));
      Prop := GetPropInfo(Parent, Copy(Path, i, j-i), [tkClass]);
      if (Prop <> nil) then
        NewParent := TPersistent(GetObjectProp(Parent, Prop, TPersistent))
      else
        NewParent := nil;
      if (NewParent = nil) then
        raise Exception.CreateFmt('Property not found or incorrect type: %s.%s', [Parent.GetNamePath, Copy(Path, i, j-i)]);
      Result := Blah(NewParent, Copy(Path, i, Length(Path)));
    end;
  end;

var
  s: string;
  i: integer;
{$ifndef STREAM_V2_IN}
  Domain: TCustomDataDictionaryDomain;
  Table: TCustomDataDictionaryTable;
  Field: TCustomDataDictionaryField;
{$endif}
  FixupValue: TObject;
  PropFixup: TPropFixup;
begin
  if (FFixups = nil) then
    exit;
//  ShowMessage(Format('Resolving %d references', [FFixups.Count]));
  // Iterate through all unresolved references (fixups) and attempt
  // to resolve them.
  Include(FState, rsFixup);
  try
    for i := FFixups.Count-1 downto 0 do
    begin
      PropFixup := FFixups[i];
{$ifndef STREAM_V2_IN}
      // Domains and Field fixups are handled differently.
      if (PropFixup.Kind = fkField) then
      begin
        (*
        ** Field fixup.
        *)
        // In order to resolve the fixup we need both the table...
        Table := Tables.FindTable(PropFixup.TableName);
        if (Table = nil) then
          continue;
        // ...and the field.
        Field := Table.Fields.FindField(PropFixup.FieldName);
        if (Field = nil) then
          continue;
        // If the fixup could be resolved, we set the reference and...
        SetOrdProp(PropFixup.Instance, PropFixup.PropInfo, Longint(Field));
        // ...remove the fixup.
        FFixups.Delete(i);
      end else
      if (PropFixup.Kind = fkDomain) then
      begin
        (*
        ** Domain fixup.
        *)
        // Determine if the fixup can be resolved.
        Domain := Domains.FindDomain(PropFixup.FieldName);
        if (Domain = nil) then
          continue;
        // If the fixup could be resolved, we set the reference and...
        SetOrdProp(PropFixup.Instance, PropFixup.PropInfo, Longint(Domain));
        // ...remove the fixup.
        FFixups.Delete(i);
      end else
      begin
{$endif}
        (*
        ** Generic fixup.
        *)
        // Recursively parse the path into a collection and an item
        ASSERT(PropFixup.Path.EndsWith(']'));
        FixupValue := Blah(Self, PropFixup.Path);

        // If the fixup could be resolved, we set the reference and...
        if (FixupValue <> nil) then
        begin
          PropFixup.CollectionItem.SetState(rsFixup);
          try
            SetObjectProp(PropFixup.CollectionItem, PropFixup.PropInfo, FixupValue);
          finally
            PropFixup.CollectionItem.ClearState(rsFixup);
          end;
        end;
        // ...remove the fixup.
        FFixups.Delete(i);
      end;
{$ifndef STREAM_V2_IN}
    end;
{$endif}
  finally
    Exclude(FState, rsFixup);
  end;

  // Display debug warning if any fixups couldn't be resolved.
  // This normally doesn't do anything since unresolved fixups are deleted
  // by the Fixup method.
  if (FFixups.Count > 0) then
  begin
    s := '';
    for PropFixup in FFixups do
{$ifndef STREAM_V2_IN}
      if (PropFixup.Kind <> fkGeneric) then
        s := s+#13+PropFixup.Instance.GetNamePath+'.'+string(PropFixup.PropInfo^.Name)
      else
{$endif}
        s := s+#13+PropFixup.CollectionItem.GetNamePath+'.'+string(PropFixup.PropInfo^.Name);
    if (csDesigning in ComponentState) then
      ShowMessage(Format('%d unresolved references:%s', [FFixups.Count, s]))
    else
      raise Exception.CreateFmt('%d unresolved references:%s', [FFixups.Count, s]);
  end else
    FreeAndNil(FFixups);
end;

procedure TCustomDataDictionary.Loaded;
(*
var
  i, j: integer;
*)
begin
  inherited Loaded;
(*
  for i := 0 to Tables.Count-1 do
    for j := 0 to Tables[i].Fields.Count-1 do
      TDataDictionaryField(Tables[i].Fields[j]).Options := TDataDictionaryField(Tables[i].Fields[j]).Options+[foReplicate];
*)
end;

procedure TCustomDataDictionary.ReadState(Reader: TReader);
begin
  Clear;
  Include(FState, rsLoading);
  try
    inherited ReadState(Reader);

    // Once everything has been loaded we fixup any properties which could not be
    // resolved during load.
    Fixup;
  finally
    Exclude(FState, rsLoading);
  end;
end;

function TCustomDataDictionary.GetDomainClass: TDataDictionaryDomainClass;
begin
  Result := TCustomDataDictionaryDomain;
end;

function TCustomDataDictionary.GetFieldClass: TDataDictionaryFieldClass;
begin
  Result := TCustomDataDictionaryField;
end;

function TCustomDataDictionary.GetTableClass: TDataDictionaryTableClass;
begin
  Result := TCustomDataDictionaryTable;
end;

function TCustomDataDictionary.GetRelationshipClass: TDataDictionaryRelationshipClass;
begin
  Result := TCustomDataDictionaryRelationship;
end;

function TCustomDataDictionary.GetIndexClass: TDataDictionaryIndexClass;
begin
  Result := TCustomDataDictionaryIndex;
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryTables
//
////////////////////////////////////////////////////////////////////////////////
constructor TDataDictionaryTables.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, FindRepository(AOwner).TableClass);
end;

function TDataDictionaryTables.FindObject(
  const Name: string): TCustomDataDictionaryTable;
var
  index			: integer;
begin
  index := IndexOfObject(Name);
  if (index <> -1) then
    Result := Tables[index]
  else
    Result := nil;
end;

function TDataDictionaryTables.FindTable(const Name: string): TCustomDataDictionaryTable;
var
  index			: integer;
begin
  index := IndexOf(Name);
  if (index <> -1) then
    Result := Tables[index]
  else
    Result := nil;
end;

function TDataDictionaryTables.GetTable(Index: integer): TCustomDataDictionaryTable;
begin
  Result := TCustomDataDictionaryTable(GetItem(Index));
end;

function TDataDictionaryTables.IndexOf(const TableName: string): integer;
begin
  Result := Count-1;
  while (Result >= 0) do
  begin
    if (AnsiSameText(Tables[Result].TableName, TableName)) then
      break;
    dec(Result);
  end;
end;

function TDataDictionaryTables.IndexOfObject(
  const ObjectName: string): integer;
begin
  Result := Count-1;
  while (Result >= 0) do
  begin
    if (AnsiSameText(Tables[Result].ObjectName, ObjectName)) then
      break;
    dec(Result);
  end;
end;

procedure TDataDictionaryTables.SetTable(Index: integer;
  const Value: TCustomDataDictionaryTable);
begin
  inherited SetItem(Index, Value);
end;

function TDataDictionaryTables.TableByName(const Name: string): TCustomDataDictionaryTable;
begin
  Result := FindTable(Name);
  if (Result = nil) then
    raise Exception.CreateFmt('Unknown table: %s', [Name]);
end;

function TDataDictionaryTables.TableByObjectName(
  const Name: string): TCustomDataDictionaryTable;
begin
  Result := FindObject(Name);
  if (Result = nil) then
    raise Exception.CreateFmt('Unknown object: %s', [Name]);
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionaryTable
//
////////////////////////////////////////////////////////////////////////////////
constructor TCustomDataDictionaryTable.Create(AOwner: TCollection);
begin
  inherited Create(AOwner);
  FFields := TDataDictionaryFields.Create(Self);
  FFields.Table := Self;
  FRelationships := TDataDictionaryRelationships.Create(Self);
  FRelationships.Table := Self;
  FIndices := TDataDictionaryIndices.Create(Self);
  FIndices.Table := Self;
  FSchema := TStringList.Create;
end;

destructor TCustomDataDictionaryTable.Destroy;
begin
  FreeAndNil(FRelationships);
  FreeAndNil(FIndices);
  FreeAndNil(FFields);
  FreeAndNil(FSchema);
  inherited Destroy;
end;

function TCustomDataDictionaryTable.GetDisplayLabel: string;
begin
  // If no display label has been specified, we use the table name.
  // As a side effect, it is not possible to specify an empty display label.
  if (FDisplayLabel <> '') then
    Result := FDisplayLabel
  else
    Result := TableName;
end;

function TCustomDataDictionaryTable.GetDisplayName: string;
begin
  // Construct the string which will be displayed in
  // the design time collection editor.
  Result := TableName;
  if Result = '' then
  begin
    Result := ObjectName;
    if Result = '' then
    begin
      Result := DisplayLabel;
      if Result = '' then
        Result := inherited GetDisplayName;
    end;
  end;
end;

function TCustomDataDictionaryTable.GetIsDetailTable: boolean;
var
  i: integer;
begin
  Result := False;
  for i := 0 to FFields.Count-1 do
    if (FFields[i].ForeignKey <> nil) then
    begin
      Result := True;
      exit;
    end;
end;

function TCustomDataDictionaryTable.GetIsMasterTable: boolean;
var
  i: integer;
begin
  Result := False;
  for i := 0 to FFields.Count-1 do
    if (FFields[i].References.Count > 0) then
    begin
      Result := True;
      exit;
    end;
end;

function TCustomDataDictionaryTable.GetObjectName: string;
begin
  if (FObjectName <> '') then
    Result := FObjectName
  else
    Result := TableName;
end;

function TCustomDataDictionaryTable.IsDisplayLabelStored: Boolean;
begin
  Result := (FDisplayLabel <> '') and (FDisplayLabel <> TableName);
end;

function TCustomDataDictionaryTable.IsIndicesStored: Boolean;
begin
  Result := (FIndices.Count > 0);
end;

function TCustomDataDictionaryTable.IsObjectNameStored: boolean;
begin
  Result := (FObjectName <> '') and (FObjectName <> TableName);
end;

function TCustomDataDictionaryTable.IsRelationshipsStored: Boolean;
begin
  Result := (FRelationships.Count > 0);
end;

procedure TCustomDataDictionaryTable.SetFields(const Value: TDataDictionaryFields);
begin
  FFields.Assign(Value);
end;

procedure TCustomDataDictionaryTable.SetIndices(
  const Value: TDataDictionaryIndices);
begin
  FIndices.Assign(Value);
end;

procedure TCustomDataDictionaryTable.SetRelationships(
  const Value: TDataDictionaryRelationships);
begin
  FRelationships.Assign(Value);
end;

procedure TCustomDataDictionaryTable.SetSchema(const Value: TStrings);
begin
  FSchema.Assign(Value);
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryDomains
//
////////////////////////////////////////////////////////////////////////////////
constructor TDataDictionaryDomains.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, FindRepository(AOwner).DomainClass);
end;

function TDataDictionaryDomains.DomainByName(const Name: string): TCustomDataDictionaryDomain;
begin
  Result := FindDomain(Name);
  if (Result = nil) then
    raise Exception.CreateFmt('Unknown domain: %s', [Name]);
end;


function TDataDictionaryDomains.FindDomain(const Name: string): TCustomDataDictionaryDomain;
var
  index			: integer;
begin
  index := IndexOf(Name);
  if (index <> -1) then
    Result := Domains[index]
  else
    Result := nil;
end;

function TDataDictionaryDomains.GetDomain(Index: integer): TCustomDataDictionaryDomain;
begin
  Result := TCustomDataDictionaryDomain(GetItem(Index));
end;

function TDataDictionaryDomains.IndexOf(const DomainName: string): integer;
begin
  Result := Count-1;
  while (Result >= 0) do
  begin
    if (AnsiSameText(Domains[Result].DomainName, DomainName)) then
      break;
    dec(Result);
  end;
end;

procedure TDataDictionaryDomains.SetDomain(Index: integer;
  const Value: TCustomDataDictionaryDomain);
begin
  inherited SetItem(Index, Value);
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionaryDomain
//
////////////////////////////////////////////////////////////////////////////////
procedure TCustomDataDictionaryDomain.Assign(Source: TPersistent);
begin
  if not(csLoading in Repository.ComponentState) then
  begin
    if (Source is TCustomDataDictionaryDomain) then
    begin
      Required := TCustomDataDictionaryDomain(Source).Required;
    end;
    inherited Assign(Source);
  end;
end;

constructor TCustomDataDictionaryDomain.Create(AOwner: TCollection);
begin
  inherited Create(AOwner);
  FChildren := TDataDictionaryDomainList.Create;
  FReferences := TDataDictionaryFieldList.Create;
end;

procedure TCustomDataDictionaryDomain.DefineProperties(Filer: TFiler);

  function DoWriteParent: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := (TCustomDataDictionaryDomain(Filer.Ancestor).Parent <> Parent)
    else
      Result := (Parent <> nil);
  end;

begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('ParentName', ReadDataParent, WriteDataParent,
    DoWriteParent);
end;

destructor TCustomDataDictionaryDomain.Destroy;
begin
  Parent := nil;

  FreeAndNil(FChildren);
  FreeAndNil(FReferences);

  inherited Destroy;
end;

function TCustomDataDictionaryDomain.GetDisplayName: string;
begin
  // Construct the string which will be displayed in
  // the design time collection editor.
  Result := DomainName;
  if Result = '' then
    Result := inherited GetDisplayName;
end;

function TCustomDataDictionaryDomain.GetQualifiedName: string;
begin
  Result := DisplayName;
end;

procedure TCustomDataDictionaryDomain.Notification(Item: TObject);
begin
  inherited Notification(Item);
  if (Item = Parent) then
    Parent := nil;
end;

procedure TCustomDataDictionaryDomain.ReadDataParent(Reader: TReader);
var
  Value: string;
begin
  Value := Reader.ReadString;
{$ifdef STREAM_V2_IN}
  Repository.AddFixup(Self, GetPropInfo(Self, 'Parent'), Value);
{$else}
  FParent := TCustomDataDictionaryDomain(Repository.Domains.ItemByName(Value));
  // If the domain references another domain which hasn't been loaded yet
  // we cannot set the property value, so we defer and add the domain to
  // the fixup list. Once all domains has been loaded, all fixups will be
  // resolved and the property set.
  if (FParent = nil) then
    Repository.AddDomainFixup(Self, GetPropInfo(Self, 'Parent'), Value);
{$endif}
end;

procedure TCustomDataDictionaryDomain.SetParent(const Value: TCustomDataDictionaryDomain);
var
  Node: TCustomDataDictionaryDomain;
begin
  if (Value <> FParent) then
  begin
    // Guard against recursive definitions by traversing the inheritance tree and
    // checking that the domain doesn't inherit from itself.
    if (not(rsLoading in State)) then
    begin
      Node := Value;
      while (Node <> nil) do
      begin
        if (Node = Self) then
          raise Exception.Create('Recursive definitions not allowed');
        Node := Node.Parent;
        if (Node = Value) then
          raise Exception.Create('Recursive definitions not allowed');
      end;
    end;

    if (FParent <> nil) then
    begin
      FParent.Unsubscribe(Self);
      FParent.Children.Remove(Self);
    end;
    FParent := Value;
    if (FParent <> nil) then
    begin
      FParent.Children.Add(Self);
      FParent.Subscribe(Self);
      Assign(FParent);
    end;
  end;
end;

procedure TCustomDataDictionaryDomain.WriteDataParent(Writer: TWriter);
begin
{$ifdef STREAM_V2_OUT}
  Writer.WriteString(Parent.GetNamePath);
{$else}
  Writer.WriteString(Parent.QualifiedName);
{$endif}
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryFields
//
////////////////////////////////////////////////////////////////////////////////
constructor TDataDictionaryFields.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, FindRepository(AOwner).FieldClass);
end;

function TDataDictionaryFields.FieldByName(const Name: string): TCustomDataDictionaryField;
begin
  Result := FindField(Name);
  if (Result = nil) then
    raise Exception.CreateFmt('Unknown field: %s', [Name]);
end;

function TDataDictionaryFields.FindField(const Name: string): TCustomDataDictionaryField;
var
  Index: integer;
begin
  Index := IndexOf(Name);
  if (Index <> -1) then
    Result := Fields[Index]
  else
    Result := nil;
end;

function TDataDictionaryFields.GetField(Index: integer): TCustomDataDictionaryField;
begin
  Result := TCustomDataDictionaryField(GetItem(Index));
end;

function TDataDictionaryFields.IndexOf(const FieldName: string): integer;
begin
  Result := Count-1;
  while (Result >= 0) do
  begin
    if (AnsiSameText(Fields[Result].FieldName, FieldName)) then
      break;
    dec(Result);
  end;
end;

procedure TDataDictionaryFields.SetField(Index: integer;
  const Value: TCustomDataDictionaryField);
begin
  inherited SetItem(Index, Value);
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionaryField
//
////////////////////////////////////////////////////////////////////////////////
procedure TCustomDataDictionaryField.Assign(Source: TPersistent);
begin
  if not(csLoading in Repository.ComponentState) then
  begin
    if (Source is TCustomDataDictionaryField) then
    begin
      Domain := TCustomDataDictionaryField(Source).Domain;
      Required := TCustomDataDictionaryField(Source).Required;
      FieldName := TCustomDataDictionaryField(Source).FieldName;
      DisplayLabel := TCustomDataDictionaryField(Source).DisplayLabel;
      ParamType := TCustomDataDictionaryField(Source).ParamType;
      DisplayWidth := TCustomDataDictionaryField(Source).DisplayWidth;
      CharCase := TCustomDataDictionaryField(Source).CharCase;
      CharCase := TCustomDataDictionaryField(Source).CharCase;
      AutoGenerateValue := TCustomDataDictionaryField(Source).AutoGenerateValue;
      Hidden := TCustomDataDictionaryField(Source).Hidden;
      Unique := TCustomDataDictionaryField(Source).Unique;
      ReadOnly := TCustomDataDictionaryField(Source).ReadOnly;
    end;
    inherited Assign(Source);
  end;
end;

constructor TCustomDataDictionaryField.Create(AOwner: TCollection);
begin
  inherited Create(AOwner);
  FReferences := TDataDictionaryFieldList.Create;
  ParamType := ptOutput;
end;

procedure TCustomDataDictionaryField.DefineProperties(Filer: TFiler);

  function DoWriteFK: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := (TCustomDataDictionaryField(Filer.Ancestor).ForeignKey <> ForeignKey)
    else
      Result := (ForeignKey <> nil);
  end;

  function DoWriteDomain: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := (TCustomDataDictionaryField(Filer.Ancestor).Domain <> Domain)
    else
      Result := (Domain <> nil);
  end;

begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('DomainName', ReadDataDomain, WriteDataDomain,
    DoWriteDomain);
  Filer.DefineProperty('ForeignKeyName', ReadDataFK, WriteDataFK, DoWriteFK);
end;

destructor TCustomDataDictionaryField.Destroy;
begin
  ASSERT(FReferences.Count = 0, Format('%s: %d', [QualifiedName, FReferences.Count]));
  Domain := nil;
  ForeignKey := nil;
  FreeAndNil(FReferences);
  inherited Destroy;
end;

function TCustomDataDictionaryField.GetDisplayLabel: string;
begin
  // If no display label has been specified, we use the field name.
  // If the field is hidden or is an input parameter field, the display label
  // is empty.
  if (Hidden) or (ParamType = ptInput) then
    Result := ''
  else if (FDisplayLabel <> '') then
    Result := FDisplayLabel
  else
    Result := FieldName;
end;

function TCustomDataDictionaryField.GetDisplayName: string;
begin
  // Construct the string which will be displayed in
  // the design time collection editor.
  Result := FieldName;
  if Result = '' then
  begin
    Result := DisplayLabel;
    if Result = '' then
      Result := inherited GetDisplayName;
  end;
end;

function TCustomDataDictionaryField.GetOrigin: string;
begin
  if (FOrigin <> '') then
    Result := FOrigin
  else
    Result := QualifiedName;
end;

function TCustomDataDictionaryField.GetQualifiedName: string;
begin
  Result := Table.TableName + '.' + FieldName;
end;

function TCustomDataDictionaryField.GetTable: TCustomDataDictionaryTable;
begin
  Result := (Collection as TDataDictionaryFields).Table;
end;

function TCustomDataDictionaryField.IsDisplayLabelStored: Boolean;
begin
  Result := (FDisplayLabel <> '') and (FDisplayLabel <> FieldName) and
    (not Hidden) and (ParamType <> ptInput);
end;

function TCustomDataDictionaryField.IsOriginStored: Boolean;
begin
  Result := (FOrigin <> '') and (FOrigin <> QualifiedName);
end;

procedure TCustomDataDictionaryField.Notification(Item: TObject);
begin
  inherited Notification(Item);
  if (Item = ForeignKey) then
    ForeignKey := nil;
  if (Item = Domain) then
    Domain := nil;
end;

procedure TCustomDataDictionaryField.ReadDataDomain(Reader: TReader);
var
  Value: string;
begin
  Value := Reader.ReadString;
{$ifdef STREAM_V2_IN}
  Repository.AddFixup(Self, GetPropInfo(Self, 'Domain'), Value);
{$else}
  FDomain := TCustomDataDictionaryDomain(Repository.Domains.ItemByName(Value));
  // If the domain references another domain which hasn't been loaded yet
  // we cannot set the property value, so we defer and add the domain to
  // the fixup list. Once all domains has been loaded, all fixups will be
  // resolved and the property set.
  if (FDomain = nil) then
    Repository.AddDomainFixup(Self, GetPropInfo(Self, 'Domain'), Value);
{$endif}
end;

procedure TCustomDataDictionaryField.ReadDataFK(Reader: TReader);
var
  Value: string;
{$ifndef STREAM_V2_IN}
  TableName, FieldName: string;
  FKTable: TCustomDataDictionaryTable;
{$endif}
begin
  Value := Reader.ReadString;
{$ifdef STREAM_V2_IN}
  Repository.AddFixup(Self, GetPropInfo(Self, 'ForeignKey'), Value);
{$else}
  TableName := Copy(Value, 1, pos('.', Value)-1);
  FieldName := Copy(Value, pos('.', Value)+1, Length(Value));
  FKTable := Repository.Tables.FindTable(TableName);
  if (FKTable <> nil) then
    ForeignKey := FKTable.Fields.FindField(FieldName);
  // If the field references another field which hasn't been loaded yet
  // we cannot set the property value, so we defer and add the field to
  // the fixup list. Once all fields has been loaded all fixups will be
  // resolved and the property set.
  if (FForeignKey = nil) then
    Repository.AddFieldFixup(Self, GetPropInfo(Self, 'ForeignKey'), TableName, FieldName);
{$endif}
end;

procedure TCustomDataDictionaryField.SetDomain(const Value: TCustomDataDictionaryDomain);
begin
  if (Value <> FDomain) then
  begin
    if (FDomain <> nil) then
    begin
      FDomain.References.Remove(Self);
      FDomain.Unsubscribe(Self);
    end;
    FDomain := Value;
    if (FDomain <> nil) then
    begin
      FDomain.References.Add(Self);
      FDomain.Subscribe(Self);
      if (not(rsLoading in State)) then
        Assign(FDomain);
    end;
  end;
end;

procedure TCustomDataDictionaryField.SetFieldName(const Value: string);
begin
  FFieldName := Value;
end;

procedure TCustomDataDictionaryField.SetForeignKey(const Value: TCustomDataDictionaryField);
begin
  if (FForeignKey <> Value) then
  begin
    if (FForeignKey <> nil) then
    begin
      ASSERT(FForeignKey.References.IndexOf(Self) <> -1);
      FForeignKey.Unsubscribe(Self);
      FForeignKey.References.Remove(Self);
    end;
    FForeignKey := Value;
    if (FForeignKey <> nil) then
    begin
      FForeignKey.References.Add(Self);
      FForeignKey.Subscribe(Self);
    end;
  end;
end;

procedure TCustomDataDictionaryField.SetHidden(const Value: boolean);
begin
  FHidden := Value;
  if (Hidden) and (not(rsLoading in State)) then
    DisplayLabel := '';
end;

procedure TCustomDataDictionaryField.SetParamType(const Value: TParamType);
begin
  FParamType := Value;
  if (ParamType = ptInput) and (not Hidden) and (not(rsLoading in State)) then
    Hidden := True;
end;

procedure TCustomDataDictionaryField.SetPrimaryKey(const Value: boolean);
begin
  FPrimaryKey := Value;
  if (PrimaryKey) and (not Required) and (not(rsLoading in State)) then
    Required := True;
end;

procedure TCustomDataDictionaryField.SetRequired(const Value: boolean);
begin
  inherited SetRequired(Value);
  if (not Required) and (Unique) and (not(rsLoading in State)) then
    Unique := False;
  if (not Required) and (PrimaryKey) and (not(rsLoading in State)) then
    PrimaryKey := False;
end;

procedure TCustomDataDictionaryField.SetUnique(const Value: boolean);
begin
  FUnique := Value;
  if (Unique) and (not Required) and (not(rsLoading in State)) then
    Required := True;
end;

procedure TCustomDataDictionaryField.WriteDataDomain(Writer: TWriter);
begin
{$ifdef STREAM_V2_OUT}
  Writer.WriteString(Domain.GetNamePath);
{$else}
  Writer.WriteString(Domain.QualifiedName);
{$endif}
end;

procedure TCustomDataDictionaryField.WriteDataFK(Writer: TWriter);
begin
{$ifdef STREAM_V2_OUT}
  Writer.WriteString(ForeignKey.GetNamePath);
{$else}
  Writer.WriteString(ForeignKey.QualifiedName);
{$endif}
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryFieldDef
//
////////////////////////////////////////////////////////////////////////////////
procedure TDataDictionaryFieldDef.Assign(Source: TPersistent);
begin
  if (Source is TDataDictionaryFieldDef) then
  begin
    DataType := TDataDictionaryFieldDef(Source).DataType;
    Precision := TDataDictionaryFieldDef(Source).Precision;
    Size := TDataDictionaryFieldDef(Source).Size;
    FieldKind := TDataDictionaryFieldDef(Source).FieldKind;
    Physical := TDataDictionaryFieldDef(Source).Physical;
    DefaultValue := TDataDictionaryFieldDef(Source).DefaultValue;
    Constraint := TDataDictionaryFieldDef(Source).Constraint;
  end else
    inherited Assign(Source);
end;

constructor TDataDictionaryFieldDef.Create(AOwner: TCollection);
begin
  inherited Create(AOwner);
end;

destructor TDataDictionaryFieldDef.Destroy;
begin
  inherited Destroy;
end;

procedure TDataDictionaryFieldDef.SetRequired(const Value: boolean);
begin
  FRequired := Value;
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionary
//
////////////////////////////////////////////////////////////////////////////////
function TDataDictionary.GetDomainClass: TDataDictionaryDomainClass;
begin
  // Specify the collection item class which should be used to represent domains.
  Result := TDataDictionaryDomain;
end;

function TDataDictionary.GetFieldClass: TDataDictionaryFieldClass;
begin
  // Specify the collection item class which should be used to represent fields.
  Result := TDataDictionaryField;
end;

function TDataDictionary.GetTableClass: TDataDictionaryTableClass;
begin
  // Specify the collection item class which should be used to represent tables.
  Result := TDataDictionaryTable;
end;


////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryField
//
////////////////////////////////////////////////////////////////////////////////
function TDataDictionaryField.CanExport: boolean;
begin
  // 1) Can't export unique primary keys unless they are also foreign keys.
  // 2) Can't export foreign keys unless master table has a NUMBER field.
  Result :=
    ((not Unique) or (ForeignKey <> nil)) and
    ((ForeignKey = nil) or (ForeignKey.Table.Fields.FindField('NUMBER') <> nil));
end;

function TDataDictionaryField.CanReplicate: boolean;
begin
  // 1) Can't replicate unique primary keys unless they are also foreign keys.
  Result := (not Unique) or (ForeignKey <> nil);
end;

constructor TDataDictionaryField.Create(AOwner: TCollection);
begin
  inherited Create(AOwner);
  FOptions := [foExport, foReplicate];
end;

function TDataDictionaryField.GetTable: TDataDictionaryTable;
begin
  Result := inherited GetTable as TDataDictionaryTable;
end;

procedure TDataDictionaryField.SetAuditMask(const Value: TUpdateKinds);
begin
  FAuditMask := Value;
  FAuditTaskMask := FAuditTaskMask * FAuditMask;
end;

procedure TDataDictionaryField.SetAuditTaskMask(const Value: TUpdateKinds);
begin
  FAuditTaskMask := Value * FAuditMask;
end;

procedure TDataDictionaryField.SetFieldName(const Value: string);
var
  UpdateExported: boolean;
  i: integer;
begin
  UpdateExported := (AnsiSameText(FieldName, 'NUMBER')) and (not AnsiSameText(Value, 'NUMBER'));

  inherited;

  if (UpdateExported) and (not(rsLoading in State)) then
  begin
    // Revalidate table export.
    if (toExport in Table.Options) and (not Table.CanExport) then
      Table.Options := Table.Options - [toExport];

    // Revalidate all detail table's and field's Export option.
    for i := 0 to References.Count-1 do
      with TDataDictionaryField(References[i]) do
      begin
        if (foExport in Options) and (not CanExport) then
          Options := Options - [foExport];
        if (toExport in Table.Options) and (not Table.CanExport) then
          Table.Options := Table.Options - [toExport];
      end;
  end;
end;

procedure TDataDictionaryField.SetForeignKey(const Value: TCustomDataDictionaryField);
begin
  inherited;

  if (not(rsLoading in State)) then
  begin
    if (ForeignKey = nil) then
    begin
      PropagateChangeLog := False;
      Options := Options - [foReplicateFromParent];
    end else
    begin
      if (foExport in Options) and (not CanExport) then
        Options := Options - [foExport];
      if (foReplicate in Options) and (not CanReplicate) then
        Options := Options - [foReplicate];

(* TODO : Don't do this on preload resolve:
      if (toReplicatable in TDataDictionaryTable(ForeignKey.Table).Options) and
        (PrimaryKey) then
        Options := Options + [foReplicateFromParent];
*)
    end;
  end;
end;

procedure TDataDictionaryField.SetOptions(Value: TDataDictionaryFieldOptions);
begin
  if not(rsLoading in State) then
  begin
    if (foExport in Value-FOptions) and (not CanExport) then
      Exclude(Value, foExport);

    if (foReplicate in Value-FOptions) and (not CanReplicate) then
      Exclude(Value, foReplicate);

    if (foReplicateFromParent in Value-FOptions) and (ForeignKey = nil) then
      Exclude(Value, foReplicateFromParent);

    if (foPropagateChangeLog in Value-FOptions) and (ForeignKey = nil) then
      Exclude(Value, foPropagateChangeLog);

    if (foReplicateInvariantKey in Value-FOptions) and (ForeignKey <> nil) then
      Exclude(Value, foReplicateInvariantKey);
  end;

  FOptions := Value;
end;

procedure TDataDictionaryField.SetPrimaryKey(const Value: boolean);
{$ifdef DD_VALIDATE_AUDIT}
var
  i: integer;
{$endif}
begin
  inherited;
  if not(rsLoading in State) then
  begin
    // Disable auditing if table has multiple primary key fields.
{$ifdef DD_VALIDATE_AUDIT}
    if (Value) and (PrimaryKey) and (toAudit in Table.Options) then
      for i := 0 to Table.Fields.Count-1 do
        if (Table.Fields[i] <> Self) and (Table.Fields[i].PrimaryKey) then
        begin
          Table.Options := Table.Options - [toAudit];
          break;
        end;
{$endif}
(* ARTICLESPLUNUMBERS.PLU breaks the following rule!
    // PrimaryKey can only be exported if it is also a foreign key and
    // master table has a NUMBER field.
    if (PrimaryKey) and (Export) and ((ForeignKey = nil) or
      (ForeignKey.Table.Fields.FindField('NUMBER') = nil)) then
      Export := False;
*)
    if (foExport in Options) and (not CanExport) then
      Options := Options - [foExport];
    if (foReplicate in Options) and (not CanReplicate) then
      Options := Options - [foReplicate];
  end;
end;

procedure TDataDictionaryField.SetPropagateChangeLog(const Value: boolean);
begin
  if (Value) then
    Options := Options + [foPropagateChangeLog]
  else
    Options := Options - [foPropagateChangeLog]
end;

procedure TDataDictionaryField.SetUnique(const Value: boolean);
begin
  inherited;
  if not(rsLoading in State) then
  begin
    if (foExport in Options) and (not CanExport) then
      Options := Options - [foExport];
    if (foReplicate in Options) and (not CanReplicate) then
      Options := Options - [foReplicate];
  end;
end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryTable
//
////////////////////////////////////////////////////////////////////////////////
function TDataDictionaryTable.CanExport: boolean;
var
  i: integer;
begin
  if (Fields.FindField('NUMBER') = nil) then
  begin
    Result := False;
    for i := 0 to Fields.Count-1 do
      if (Fields[i].ForeignKey <> nil) and
        (Fields[i].ForeignKey.Table.Fields.FindField('NUMBER') <> nil) then
      begin
        Result := True;
        exit;
      end;
  end else
    Result := True;
end;

constructor TDataDictionaryTable.Create(AOwner: TCollection);
begin
  inherited Create(AOwner);
  FOptions := [toExport, toReplicatable];
end;

procedure TDataDictionaryTable.SetReplicate(const Value: boolean);
begin
  if (Value) then
    Options := Options + [toReplicate]
  else
    Options := Options - [toReplicate];
end;

procedure TDataDictionaryTable.SetOptions(Value: TDataDictionaryTableOptions);
{$ifdef DD_VALIDATE_AUDIT}
var
  i: integer;
  PKCount: integer;
{$endif}
begin
  if (not(rsLoading in State)) then
  begin
    if (toReplicatable in FOptions - Value) then // Clearing toReplicatable
      Exclude(Value, toReplicate);
    if (toReplicate in Value-FOptions) then // Setting toReplicate
      Include(Value, toReplicatable);

    // The table can only be exported if it has a NUMBER field or
    // if it has a master table which has a NUMBER field.
    if (toExport in FOptions - Value) and (not CanExport) then
      Exclude(Value, toExport);

    // In order to audit, the table must have exactly 1 primary key.
{$ifdef DD_VALIDATE_AUDIT}
    if (toAudit in FOptions - Value) then
    begin
      PKCount := 0;
      for i := 0 to Fields.Count-1 do
        if (Fields[i].PrimaryKey) then
        begin
          inc(PKCount);
          if (PKCount > 1) then
            break;
        end;

      if (PKCount <> 1) then
        Exclude(Value, toAudit);
    end;
{$endif}
  end;

  FOptions := Value;
end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryFieldList
//
////////////////////////////////////////////////////////////////////////////////
function TDataDictionaryFieldList.Add(AField: TCustomDataDictionaryField): integer;
begin
  Result := inherited Add(AField);
end;

function TDataDictionaryFieldList.FieldByName(const Name: string): TCustomDataDictionaryField;
var
  i: integer;
begin
  for i := 0 to Count-1 do
    if (AnsiSameText(Name, TCustomDataDictionaryField(Items[i]).FieldName)) then
    begin
      Result := TCustomDataDictionaryField(Items[i]);
      exit;
    end;
  Result := nil;
end;

function TDataDictionaryFieldList.GetField(Index: integer): TCustomDataDictionaryField;
begin
  Result := TCustomDataDictionaryField(Items[Index]);
end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryDomainList
//
////////////////////////////////////////////////////////////////////////////////
function TDataDictionaryDomainList.Add(ADomain: TCustomDataDictionaryDomain): integer;
begin
  Result := inherited Add(ADomain);
end;

function TDataDictionaryDomainList.DomainByName(const Name: string): TCustomDataDictionaryDomain;
var
  i: integer;
begin
  for i := 0 to Count-1 do
    if (AnsiSameText(Name, TCustomDataDictionaryDomain(Items[i]).DomainName)) then
    begin
      Result := TCustomDataDictionaryDomain(Items[i]);
      exit;
    end;
  Result := nil;
end;

function TDataDictionaryDomainList.GetDomain(Index: integer): TCustomDataDictionaryDomain;
begin
  Result := TCustomDataDictionaryDomain(Items[Index]);
end;

////////////////////////////////////////////////////////////////////////////////
//
//              TCustomDataDictionaryRelationship
//
////////////////////////////////////////////////////////////////////////////////

procedure TReferentialIntegrityRules.Assign(Source: TPersistent);
var
  i: TReferentialIntegrityRule;
begin
  if (Source is TReferentialIntegrityRules) then
  begin
    for i := Low(FValues) to High(FValues) do
      FValues[i] := TReferentialIntegrityRules(Source)[i];
  end else
    inherited Assign(Source);
end;

constructor TReferentialIntegrityRules.Create;
begin
  inherited Create;
  FMask := [riNone..riCascade]; 
end;

destructor TReferentialIntegrityRules.Destroy;
begin
  inherited Destroy;

end;

function TReferentialIntegrityRules.GetValue(Index: TReferentialIntegrityRule): TReferentialIntegrityAction;
begin
  Result := FValues[Index];
end;

procedure TReferentialIntegrityRules.SetMask(const Value: TReferentialIntegrityActions);
var
  i: TReferentialIntegrityRule;
  j: TReferentialIntegrityAction;
begin
  if (Value = []) then
    raise Exception.Create('Empty TReferentialIntegrityRules mask not allowed');

  FMask := Value;
  for i := Low(FValues) to High(FValues) do
  begin
    // Jump through a hoop to work around compiler bug which causes AV.
    // Original statement was (not (FValues[i] in FMask)).
    j := FValues[i];
    if ([j] * FMask = []) then
    begin
      // Find first allowed value from mask
      j := Low(TReferentialIntegrityAction);
      while (not(j in FMask)) and (j < High(TReferentialIntegrityAction)) do
        inc(j);
      FValues[i] := j;
    end;
  end;
end;

procedure TReferentialIntegrityRules.SetValue(Index: TReferentialIntegrityRule;
  const Value: TReferentialIntegrityAction);
begin
  if (Value in Mask) then
    FValues[Index] := Value;
end;

procedure TReferentialIntegrity.Assign(Source: TPersistent);
var
  i: TReferentialIntegrityMember;
begin
  if (Source is TReferentialIntegrity) then
  begin
    for i := Low(FValues) to High(FValues) do
      FValues[i].Assign(TReferentialIntegrity(Source)[i]);
  end else
    inherited Assign(Source);
end;

constructor TReferentialIntegrity.Create;
var
  i: TReferentialIntegrityMember;
begin
  inherited Create;
  for i := Low(FValues) to High(FValues) do
    FValues[i] := TReferentialIntegrityRules.Create;
end;

destructor TReferentialIntegrity.Destroy;
var
  i: TReferentialIntegrityMember;
begin
  for i := Low(FValues) to High(FValues) do
    FreeAndNil(FValues[i]);
  inherited Destroy;
end;

function TReferentialIntegrity.GetMask: TReferentialIntegrityActions;
begin
  Result := FValues[rmChild].Mask;
end;

function TReferentialIntegrity.GetValue(Index: TReferentialIntegrityMember): TReferentialIntegrityRules;
begin
  Result := FValues[Index];
end;

procedure TReferentialIntegrity.SetMask(const Value: TReferentialIntegrityActions);
var
  i: TReferentialIntegrityMember;
begin
  for i := Low(FValues) to High(FValues) do
    FValues[i].Mask := Value;
end;

procedure TReferentialIntegrity.SetValue(Index: TReferentialIntegrityMember; Value: TReferentialIntegrityRules);
begin
  FValues[Index].Assign(Value);
end;

constructor TCustomDataDictionaryRelationship.Create(AOwner: TCollection);
begin
  inherited Create(AOwner);

  FFields := TDataDictionaryRelationshipFields.Create(Self);
  FFields.Relationship := Self;

  FReferentialIntegrity := TReferentialIntegrity.Create;

  FCardinality := caZeroPlus;
  FCardinalityCount := 0;
  FIdentifying := False;
end;

procedure TCustomDataDictionaryRelationship.DefineProperties(Filer: TFiler);
  function DoWriteChildTable: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := (TCustomDataDictionaryRelationship(Filer.Ancestor).ChildTable <> ChildTable)
    else
      Result := (ChildTable <> nil);
  end;
  function DoWriteParentIndex: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := (TCustomDataDictionaryRelationship(Filer.Ancestor).ParentIndex <> ParentIndex)
    else
      Result := (ParentIndex <> nil);
  end;
  function DoWriteChildIndex: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := (TCustomDataDictionaryRelationship(Filer.Ancestor).ChildIndex <> ChildIndex)
    else
      Result := (ChildIndex <> nil);
  end;
begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('ChildTableName', ReadDataChildTable, WriteDataChildTable, DoWriteChildTable);
  Filer.DefineProperty('ParentIndexName', ReadDataParentIndex, WriteDataParentIndex, DoWriteParentIndex);
  Filer.DefineProperty('ChildIndexName', ReadDataChildIndex, WriteDataChildIndex, DoWriteChildIndex);
end;

destructor TCustomDataDictionaryRelationship.Destroy;
begin
  ChildTable := nil;
  ParentIndex := nil;
  ChildIndex := nil;
  FreeAndNil(FFields);
  FreeAndNil(FReferentialIntegrity);
  inherited Destroy;
end;

function TCustomDataDictionaryRelationship.GetDisplayName: string;
begin
  Result := Name;
  if (Result = '') then
  begin
    if (ParentTable <> nil) then
      Result := ParentTable.TableName+'->'
    else
      Result := '(none)->';
    if (ChildTable <> nil) then
      Result := Result+ChildTable.TableName
    else
      Result := Result+'(none)';
  end;
end;

function TCustomDataDictionaryRelationship.GetParentTable: TCustomDataDictionaryTable;
begin
  Result := (Collection as TDataDictionaryRelationships).Table;
end;

procedure TCustomDataDictionaryRelationship.ImportFields;
var
  i: integer;
  Field: TCustomDataDictionaryField;
begin
  if (ParentIndex <> nil) then
    // Get fields from Index definition
    for i := 0 to ParentIndex.Fields.Count-1 do
      with (Fields.Add as TDataDictionaryRelationshipField) do
      begin
        ParentField := ParentIndex.Fields[i].Field;

        // Get the child fields while we are at it.
        if (ChildIndex <> nil) then
        begin
          ChildField := ChildIndex.Fields[i].Field;
        end else
        if (ChildTable <> nil) then
        begin
          // TODO: We could find the child field via Field.ForeignKey, but this only
          // works if it is the field that controls FKness and not the relation. Which is it to be?
          Field := ChildTable.Fields.FindField(ParentField.FieldName);
          // Note: This only works if the FK fields are named the same as the PK fields
          if (Field <> nil) and (Field <> ParentField) then
          begin
            if ((not Identifying) or (Field.PrimaryKey)) and
              ((not Required) or (Field.Required)) then
            ChildField := Field;
          end;
        end;
      end;
end;

procedure TCustomDataDictionaryRelationship.Notification(Item: TObject);
begin
  inherited Notification(Item);
  if (Item = ChildTable) then
    ChildTable := nil;
  if (Item = ParentIndex) then
    ParentIndex := nil;
  if (Item = ChildIndex) then
    ChildIndex := nil;
(*
  if (FFields <> nil) then
    FFields.Notification(Item);
*)
end;

procedure TCustomDataDictionaryRelationship.ReadDataChildIndex(
  Reader: TReader);
var
  Value: string;
begin
  Value := Reader.ReadString;
  Repository.AddFixup(Self, GetPropInfo(Self, 'ChildIndex'), Value);
end;

procedure TCustomDataDictionaryRelationship.ReadDataChildTable(
  Reader: TReader);
var
  Value: string;
begin
  Value := Reader.ReadString;
  Repository.AddFixup(Self, GetPropInfo(Self, 'ChildTable'), Value);
end;

procedure TCustomDataDictionaryRelationship.ReadDataParentIndex(
  Reader: TReader);
var
  Value: string;
begin
  Value := Reader.ReadString;
  Repository.AddFixup(Self, GetPropInfo(Self, 'ParentIndex'), Value);
end;

procedure TCustomDataDictionaryRelationship.SetCardinality(const Value: TCardinality);
begin
  if (FCardinality <> Value) then
  begin
    FCardinality := Value;
    if (not(rsLoading in State)) then
    begin
      if (Cardinality = caExactly) then
        CardinalityCount := 1
      else
        FCardinalityCount := 0;
    end;
  end;
end;

procedure TCustomDataDictionaryRelationship.SetCardinalityCount(
  const Value: integer);
begin
  if (rsLoading in State) then
    FCardinalityCount := Value
  else
  if (Value > 0) and (FCardinalityCount <> Value) then
  begin
    if (Cardinality <> caExactly) then
      Cardinality := caExactly;
    FCardinalityCount := Value;
  end;
end;

procedure TCustomDataDictionaryRelationship.SetChildIndex(
  const Value: TCustomDataDictionaryIndex);
var
  i: integer;
begin
  if (FChildIndex <> Value) then
  begin
    if (FChildIndex <> nil) then
      FChildIndex.Unsubscribe(Self);
    if (not(rsLoading in State)) then
    begin
      if (Value <> nil) and (not (Value.IndexType in [itPrimaryKey, itForeignKey])) then // Identifying relationship can use PK index
        raise Exception.Create('Relationship Child Index must be of type Primary or Foreign Key');
      if (Value <> nil) and (Required) and (not Value.Unique) then
        raise Exception.Create('Required Relationship Child Index must be unique');
      if (Value <> nil) and (Value.Table <> ChildTable) then
        raise Exception.Create('Relationship Child Index must belong to Child Table');
    end;
    FChildIndex := Value;
    if (FChildIndex <> nil) then
    begin
      FChildIndex.Subscribe(Self);

      // if Relationship already contains all the correct field, and nothing else,
      // we let it keep the current definition
      if (not(rsLoading in State)) and (ParentIndex <> nil) then
      begin
        if (Fields.Count = Value.Fields.Count) then
        begin
          for i := 0 to Fields.Count-1 do
            if (Fields[i].ChildField = nil) or (Value.Fields.FindField(Fields[i].ChildField.FieldName) = nil) then
            begin
              Fields.Clear;
              break;
            end;
        end else
          Fields.Clear;
        if (Fields.Count = 0) then
          ImportFields;
      end;
    end;
  end;
end;

procedure TCustomDataDictionaryRelationship.SetChildTable(
  const Value: TCustomDataDictionaryTable);
var
  i: integer;
  NewField: TCustomDataDictionaryField;
begin
  if (FChildTable <> Value) then
  begin
    if (FChildTable <> nil) then
      FChildTable.Unsubscribe(Self);

    if (not(rsLoading in State)) then
    begin
      // Clear existing child fields unless they also exist in new table
      for i := 0 to Fields.Count-1 do
      begin
        if (Value <> nil) then
        begin
          // First try existing child field name
          NewField := Value.Fields.FindField(Fields[i].ChildField.FieldName);
          // If that failed, try parent field name
          if (NewField = nil) then
            NewField := Value.Fields.FindField(Fields[i].ParentField.FieldName);
        end else
          NewField := nil;
        Fields[i].ChildField := NewField;
      end;
    end;

    FChildTable := Value;

    if (FChildTable <> nil) then
      FChildTable.Subscribe(Self);
  end;
end;

procedure TCustomDataDictionaryRelationship.SetFields(
  const Value: TDataDictionaryRelationshipFields);
begin
  FFields.Assign(Value);
end;

procedure TCustomDataDictionaryRelationship.SetIdentifying(
  const Value: boolean);
begin
  if (FIdentifying <> Value) then
  begin
    if (Value) and (not(rsLoading in State)) then
      Required := True;
    FIdentifying := Value;
    UpdateMask;
  end;
end;

procedure TCustomDataDictionaryRelationship.SetParentIndex(
  const Value: TCustomDataDictionaryIndex);
var
  i: integer;
begin
  if (FParentIndex <> Value) then
  begin
    if (FParentIndex <> nil) then
      FParentIndex.Unsubscribe(Self);
    if (not(rsLoading in State)) then
    begin
      if (Value <> nil) and (not(Value.IndexType in [itPrimaryKey, itAlternateKey])) then
        raise Exception.Create('Relationship Parent Index must be of type Primary Key or Alternate Key');
      if (Value <> nil) and (not Value.Unique) then
        raise Exception.Create('Relationship Parent Index must be unique');
      if (Value <> nil) and (Value.Table <> ParentTable) then
        raise Exception.Create('Relationship Parent Index must belong to Parent Table');
    end;
    FParentIndex := Value;
    if (FParentIndex <> nil) then
    begin
      FParentIndex.Subscribe(Self);

      // if Relationship already contains all the correct field, and nothing else,
      // we let it keep the current definition
      if (not(rsLoading in State)) then
      begin
        if (Fields.Count = Value.Fields.Count) then
        begin
          for i := 0 to Value.Fields.Count-1 do
            if (Value.Fields.FindField(Fields[i].ParentField.FieldName) = nil) then
            begin
              Fields.Clear;
              break;
            end;
        end else
          Fields.Clear;
        if (Fields.Count = 0) then
          ImportFields;
      end;
    end;
  end;
end;

procedure TCustomDataDictionaryRelationship.SetReferentialIntegrity(
  const Value: TReferentialIntegrity);
begin
  FReferentialIntegrity.Assign(Value);
end;

procedure TCustomDataDictionaryRelationship.SetRequired(
  const Value: boolean);
var
  i: integer;
begin
  if (FRequired <> Value) then
  begin
    if (not Identifying) or (rsLoading in State) then
    begin
      if (not Value) and (not(rsLoading in State)) then
      begin
        // Verify that FK fields allow NULL
        for i := 0 to Fields.Count-1 do
          if (Fields[i].ChildField.Required) then
            raise Exception.CreateFmt('Relationship must be required because child field %s is required',
              [Fields[i].ChildField.QualifiedName]);
      end;
      FRequired := Value;
      if (not FRequired) and (not(rsLoading in State)) then
        Identifying := False;
      UpdateMask;
    end;
  end;
end;

procedure TCustomDataDictionaryRelationship.UpdateMask;
var
  NewMask: TReferentialIntegrityActions;
begin
  NewMask := [riNone..riCascade];
  if (FIdentifying) then
    NewMask := NewMask-[riSetNull, riSetDefault];
  if (FRequired) then
    NewMask := NewMask-[riSetNull];
  ReferentialIntegrity.Mask := NewMask;
end;

procedure TCustomDataDictionaryRelationship.WriteDataChildIndex(
  Writer: TWriter);
begin
  Writer.WriteString(ChildIndex.GetNamePath);
end;

procedure TCustomDataDictionaryRelationship.WriteDataChildTable(
  Writer: TWriter);
begin
  Writer.WriteString(ChildTable.GetNamePath);
end;

procedure TCustomDataDictionaryRelationship.WriteDataParentIndex(
  Writer: TWriter);
begin
  Writer.WriteString(ParentIndex.GetNamePath);
end;

{ TDataDictionaryRelationshipFields }

constructor TDataDictionaryRelationshipFields.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TDataDictionaryRelationshipField);
end;

function TDataDictionaryRelationshipFields.FieldByChildName(
  const Name: string): TDataDictionaryRelationshipField;
begin
  Result := FindChildField(Name);
  if (Result = nil) then
    raise Exception.CreateFmt('Unknown child field: %s', [Name]);
end;

function TDataDictionaryRelationshipFields.FieldByParentName(
  const Name: string): TDataDictionaryRelationshipField;
begin
  Result := FindParentField(Name);
  if (Result = nil) then
    raise Exception.CreateFmt('Unknown parent field: %s', [Name]);
end;

function TDataDictionaryRelationshipFields.FindChildField(
  const Name: string): TDataDictionaryRelationshipField;
var
  Index: integer;
begin
  Index := IndexOfChild(Name);
  if (Index <> -1) then
    Result := Fields[Index]
  else
    Result := nil;
end;

function TDataDictionaryRelationshipFields.FindParentField(
  const Name: string): TDataDictionaryRelationshipField;
var
  Index: integer;
begin
  Index := IndexOfParent(Name);
  if (Index <> -1) then
    Result := Fields[Index]
  else
    Result := nil;
end;

function TDataDictionaryRelationshipFields.GetField(Index: integer): TDataDictionaryRelationshipField;
begin
  Result := TDataDictionaryRelationshipField(Items[Index]);
end;

function TDataDictionaryRelationshipFields.IndexOfChild(const Name: string): integer;
begin
  Result := Count-1;
  while (Result >= 0) do
  begin
    if (AnsiSameText(Fields[Result].ChildField.FieldName, Name)) then
      break;
    dec(Result);
  end;
end;

function TDataDictionaryRelationshipFields.IndexOfParent(
  const Name: string): integer;
begin
  Result := Count-1;
  while (Result >= 0) do
  begin
    if (AnsiSameText(Fields[Result].ParentField.FieldName, Name)) then
      break;
    dec(Result);
  end;
end;

procedure TDataDictionaryRelationshipFields.SetField(Index: integer;
  const Value: TDataDictionaryRelationshipField);
begin
  Items[Index] := Value;
end;

{ TDataDictionaryRelationshipField }

procedure TDataDictionaryRelationshipField.DefineProperties(Filer: TFiler);
  function DoWriteParentField: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := (TDataDictionaryRelationshipField(Filer.Ancestor).ParentField <> ParentField)
    else
      Result := (ParentField <> nil);
  end;
  function DoWriteChildField: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := (TDataDictionaryRelationshipField(Filer.Ancestor).ChildField <> ChildField)
    else
      Result := (ChildField <> nil);
  end;
begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('ParentFieldName', ReadDataParentField, WriteDataParentField, DoWriteParentField);
  Filer.DefineProperty('ChildFieldName', ReadDataChildField, WriteDataChildField, DoWriteChildField);
end;

destructor TDataDictionaryRelationshipField.Destroy;
begin
  ParentField := nil;
  ChildField := nil;
  inherited Destroy;
end;

function TDataDictionaryRelationshipField.GetDisplayName: string;
begin
  if (ParentField <> nil) then
    Result := ParentField.QualifiedName+'->'
  else
    Result := '(none)->';
  if (ChildField <> nil) then
    Result := Result+ChildField.QualifiedName
  else
    Result := Result+'(none)';
end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryRelationships
//
////////////////////////////////////////////////////////////////////////////////

function TDataDictionaryRelationshipField.GetRelationship: TCustomDataDictionaryRelationship;
begin
  Result := (Collection as TDataDictionaryRelationshipFields).Relationship;
end;

procedure TDataDictionaryRelationshipField.Notification(Item: TObject);
begin
  inherited Notification(Item);
  if (Item = ChildField) then
    ChildField := nil;
  if (Item = ParentField) then
    ParentField := nil;
end;

procedure TDataDictionaryRelationshipField.ReadDataChildField(
  Reader: TReader);
var
  Value: string;
begin
  Value := Reader.ReadString;
  Repository.AddFixup(Self, GetPropInfo(Self, 'ChildField'), Value);
end;

procedure TDataDictionaryRelationshipField.ReadDataParentField(
  Reader: TReader);
var
  Value: string;
begin
  Value := Reader.ReadString;
  Repository.AddFixup(Self, GetPropInfo(Self, 'ParentField'), Value);
end;

procedure TDataDictionaryRelationshipField.SetChild(
  const Value: TCustomDataDictionaryField);
begin
  if (FChild <> Value) then
  begin
    if (Value = FParent) and (FParent <> nil) and (not(rsLoading in State)) then
      raise Exception.Create('Cannot link field to itself');

    if (Value <> nil) and (not(rsLoading in State)) then
    begin
      // Check for FK constraint violation
      if (Relationship.Required) and (not Value.Required) then
      begin
        if (csDesigning in Repository.ComponentState) then
        begin
          if (MessageDlg('Child field violates Relationship NOT NULL requirement',
            mtWarning, [mbCancel, mbIgnore], 0) = mrCancel) then
            exit;
        end else
          raise Exception.Create('Child field violates Relationship NOT NULL requirement');
      end;
      if (Relationship.Identifying) and (not Value.PrimaryKey) then
      begin
        if (csDesigning in Repository.ComponentState) then
        begin
          if (MessageDlg('The relationship is identifying, but the child field is not part of the primary key',
            mtWarning, [mbCancel, mbIgnore], 0) = mrCancel) then
            exit;
        end else
          raise Exception.Create('The relationship is identifying, but the child field is not part of the primary key');
      end;
    end;

    if (FChild <> nil) then
    begin
      FChild.Unsubscribe(Self);
      FChild.ForeignKey := nil;
    end;

    FChild := Value;

    if (FChild <> nil) then
    begin
      if (not(rsLoading in State)) then
        FChild.ForeignKey := FParent;

      FChild.Subscribe(Self);
      if (csDesigning in Repository.ComponentState) and (not(rsLoading in State)) then
      begin
        // Design time warnings
        if (FParent <> nil) and (FChild.DataType <> FParent.DataType) then
//          ShowMessage(GetSetProp(Repository, 'State', True))
          MessageDlg('Child and Parent fields are not of the same Data Type', mtWarning, [mbOK], 0)
        else
        if (FParent <> nil) and (FChild.Domain <> FParent.Domain) then
          MessageDlg('Child and Parent fields are not of the same Domain', mtWarning, [mbOK], 0);
      end;
    end;
  end;
end;

procedure TDataDictionaryRelationshipField.SetParent(const Value: TCustomDataDictionaryField);
begin
  if (FParent <> Value) then
  begin
    if (Value = FChild) and (FChild <> nil) and (not(rsLoading in State)) then
      raise Exception.Create('Cannot link field to itself');

    if (FParent <> nil) then
      FParent.Unsubscribe(Self);

    FParent := Value;

    if (FParent <> nil) then
    begin
      FParent.Subscribe(Self);

      if (not(rsLoading in State)) and (FChild <> nil) then
        FChild.ForeignKey := FParent;

      if (csDesigning in Repository.ComponentState) and (not(rsLoading in State)) then
      begin
        // Design time warnings
        if (FChild <> nil) and (FChild.DataType <> FParent.DataType) then
          MessageDlg('Child and Parent fields are not of the same Data Type', mtWarning, [mbOK], 0)
        else
        if (FChild <> nil) and (FChild.Domain <> FParent.Domain) then
          MessageDlg('Child and Parent fields are not of the same Domain', mtWarning, [mbOK], 0);
      end;
    end;
  end;
end;

procedure TDataDictionaryRelationshipField.WriteDataChildField(
  Writer: TWriter);
begin
  Writer.WriteString(ChildField.GetNamePath);
end;

procedure TDataDictionaryRelationshipField.WriteDataParentField(
  Writer: TWriter);
begin
  Writer.WriteString(ParentField.GetNamePath);
end;

{ TDataDictionaryRelationships }

constructor TDataDictionaryRelationships.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, FindRepository(AOwner).RelationshipClass);
end;

function TDataDictionaryRelationships.FindRelationship(
  const Name: string): TCustomDataDictionaryRelationship;
var
  Index: integer;
begin
  Index := IndexOf(Name);
  if (Index <> -1) then
    Result := Relationships[index]
  else
    Result := nil;
end;

function TDataDictionaryRelationships.GetRelationship(Index: integer): TCustomDataDictionaryRelationship;
begin
  Result := TCustomDataDictionaryRelationship(Items[Index]);
end;

function TDataDictionaryRelationships.IndexOf(const Name: string): integer;
begin
  Result := Count-1;
  while (Result >= 0) do
  begin
    if (AnsiSameText(Relationships[Result].Name, Name)) then
      break;
    dec(Result);
  end;
end;

function TDataDictionaryRelationships.RelationshipByName(
  const Name: string): TCustomDataDictionaryRelationship;
begin
  Result := FindRelationship(Name);
  if (Result = nil) then
    raise Exception.CreateFmt('Unknown relationship: %s', [Name]);
end;

procedure TDataDictionaryRelationships.SetRelationship(Index: integer; const Value: TCustomDataDictionaryRelationship);
begin
  Items[Index] := Value;
end;

////////////////////////////////////////////////////////////////////////////////
//
//      TDataDictionaryIndices
//
////////////////////////////////////////////////////////////////////////////////
constructor TDataDictionaryIndices.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, FindRepository(AOwner).IndexClass);
end;

function TDataDictionaryIndices.FindIndex(const Name: string): TCustomDataDictionaryIndex;
var
  Index: integer;
begin
  Index := IndexOf(Name);
  if (Index <> -1) then
    Result := Indices[index]
  else
    Result := nil;
end;

function TDataDictionaryIndices.GetIndex(Index: integer): TCustomDataDictionaryIndex;
begin
  Result := TCustomDataDictionaryIndex(GetItem(Index));
end;

function TDataDictionaryIndices.IndexByName(const Name: string): TCustomDataDictionaryIndex;
begin
  Result := FindIndex(Name);
  if (Result = nil) then
    raise Exception.CreateFmt('Unknown index: %s', [Name]);
end;

function TDataDictionaryIndices.IndexOf(const Name: string): integer;
begin
  Result := Count-1;
  while (Result >= 0) do
  begin
    if (AnsiSameText(Indices[Result].Name, Name)) then
      break;
    dec(Result);
  end;
end;

procedure TDataDictionaryIndices.SetIndex(Index: integer;
  const Value: TCustomDataDictionaryIndex);
begin
  inherited SetItem(Index, Value);
end;

////////////////////////////////////////////////////////////////////////////////
//
//      TCustomDataDictionaryIndex
//
////////////////////////////////////////////////////////////////////////////////
constructor TCustomDataDictionaryIndex.Create(AOwner: TCollection);
begin
  inherited Create(AOwner);
  FFields := TDataDictionaryIndexFields.Create(Self);
  FFields.Index := Self;
  FIndexType := itInversionEntry;
  FSortOrder := soAscending;
end;

destructor TCustomDataDictionaryIndex.Destroy;
begin
  FreeAndNil(FFields);
  inherited Destroy;
end;

function TCustomDataDictionaryIndex.GetDisplayName: string;
begin
  // Construct the string which will be displayed in
  // the design time collection editor.
  Result := Name;
  if Result = '' then
    Result := inherited GetDisplayName;
end;

function TCustomDataDictionaryIndex.GetTable: TCustomDataDictionaryTable;
begin
  Result := (Collection as TDataDictionaryIndices).Table;
end;

procedure TCustomDataDictionaryIndex.SetFields(const Value: TDataDictionaryIndexFields);
begin
  FFields.Assign(Value);
end;

procedure TCustomDataDictionaryIndex.SetIndexType(const Value: TIndexType);
var
  i: integer;
begin
  if (FIndexType <> Value) then
  begin
    // Allow only one PK index
    if (Value = itPrimaryKey) and (not(rsLoading in State)) then
      for i := 0 to Collection.Count-1 do
        if (Collection.Items[i] <> Self) and
          (TCustomDataDictionaryIndex(Collection.Items[i]).IndexType = itPrimaryKey) then
          TCustomDataDictionaryIndex(Collection.Items[i]).IndexType := itAlternateKey;
    FIndexType := Value;
    if (FIndexType in [itPrimaryKey, itAlternateKey]) then
      Unique := True;
  end;
end;

procedure TCustomDataDictionaryIndex.SetUnique(const Value: boolean);
begin
  if (FUnique <> Value) then
  begin
    if (FIndexType = itPrimaryKey) then
      FUnique := True
    else
      FUnique := Value;
    if (FIndexType = itAlternateKey) and (not FUnique) then
      FIndexType := itInversionEntry
    else
    if (FIndexType = itInversionEntry) and (FUnique) then
      FIndexType := itAlternateKey;
  end;
end;

{ TDataDictionaryIndexField }

procedure TDataDictionaryIndexField.DefineProperties(Filer: TFiler);
  function DoWriteField: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := (TDataDictionaryIndexField(Filer.Ancestor).Field <> Field)
    else
      Result := (Field <> nil);
  end;
begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('FieldName', ReadDataField, WriteDataField,
    DoWriteField);
end;

destructor TDataDictionaryIndexField.Destroy;
begin
  Field := nil;
  inherited Destroy;
end;

function TDataDictionaryIndexField.GetDisplayName: string;
begin
  // Construct the string which will be displayed in
  // the design time collection editor.
  if (Field <> nil) then
    Result := Field.DisplayName
  else
    Result := '(none)'
end;

function TDataDictionaryIndexField.GetIndex: TCustomDataDictionaryIndex;
begin
  Result := (Collection as TDataDictionaryIndexFields).Index;
end;

procedure TDataDictionaryIndexField.Notification(Item: TObject);
begin
  inherited Notification(Item);
  if (Item = FField) then
    Field := nil;
end;

procedure TDataDictionaryIndexField.ReadDataField(Reader: TReader);
var
  Value: string;
begin
  Value := Reader.ReadString;
  Repository.AddFixup(Self, GetPropInfo(Self, 'Field'), Value);
end;

procedure TDataDictionaryIndexField.SetField(const Value: TCustomDataDictionaryField);
begin
  if (Value <> FField) then
  begin
    if (FField <> nil) then
      FField.Unsubscribe(Self);
    FField := Value;
    if (FField <> nil) then
      FField.Subscribe(Self);
  end;
end;

procedure TDataDictionaryIndexField.WriteDataField(Writer: TWriter);
begin
  Writer.WriteString(Field.GetNamePath);
end;

{ TDataDictionaryIndexFields }

constructor TDataDictionaryIndexFields.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TDataDictionaryIndexField);
end;

function TDataDictionaryIndexFields.FieldByName(const Name: string): TDataDictionaryIndexField;
begin
  Result := FindField(Name);
  if (Result = nil) then
    raise Exception.CreateFmt('Unknown field: %s', [Name]);
end;

function TDataDictionaryIndexFields.FindField(const Name: string): TDataDictionaryIndexField;
var
  Index: integer;
begin
  Index := IndexOf(Name);
  if (Index <> -1) then
    Result := Fields[Index]
  else
    Result := nil;
end;

function TDataDictionaryIndexFields.GetField(Index: integer): TDataDictionaryIndexField;
begin
  Result := TDataDictionaryIndexField(Items[Index]);
end;

function TDataDictionaryIndexFields.IndexOf(const Name: string): integer;
begin
  Result := Count-1;
  while (Result >= 0) do
  begin
    if (AnsiSameText(Fields[Result].Field.FieldName, Name)) then
      break;
    dec(Result);
  end;
end;

procedure TDataDictionaryIndexFields.SetField(Index: integer; const Value: TDataDictionaryIndexField);
begin
  Items[Index] := Value;
end;

end.
