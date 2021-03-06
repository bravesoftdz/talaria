unit dnmp_unit;

interface
uses SysUtils, Classes, Contnrs, IniFiles, DataStorage;

type
  TNodeID = Cardinal;
  TPointID = Cardinal;

  TAddr = record
    Node: TNodeID;
    Point: TPointID;
  end;

  TSeenBy = array of TNodeID;

  TDnmpManager = class;
  TDnmpMsgHandler = class;

  { TDnmpConf }

  TDnmpConf = class(TMemIniFile);

  {
  TDnmpSerializableObject = class(TInterfacedObject)
  public
    function ToStorage(): TDataStorage; virtual;
    function FromStorage(Storage: TDataStorage): Boolean; virtual;
    // Читает из цифрового потока AStream
    function FromStream(AStream: TStream): Boolean; virtual;
    // Пишет в цифровой поток AStream
    function ToStream(AStream: TStream): Boolean; virtual;
    // Читает из строки Str. Формат строки - цифровой поток
    function FromString(Str: AnsiString): Boolean; virtual;
    // Возвращает в виде строки. Формат строки - цифровой поток
    function ToString(): AnsiString; reintroduce;
  end;
  }

  { TDnmpMsg Single message. Refcounted. }

  TDnmpMsg = class(TInterfacedObject)
  //private
  public
    MsgType: AnsiString;
    TimeStamp: TDateTime;
    SerialNum: LongWord; // uint32
    SourceAddr: TAddr;
    TargetAddr: TAddr;
    Info: TStringList;
    Data: TMemoryStream;
    SeenBy: TSeenBy;
    constructor Create();
    constructor Create(SAddr, TAddr: TAddr; AMsgType, Params, DataStr: string); overload;
    destructor Destroy(); override;
    /// Читает сообщение из цифрового потока AStream
    function FromStream(AStream: TStream): Boolean;
    /// Пишет сообщение в цифровой поток AStream
    function ToStream(AStream: TStream): Boolean;
    /// Читает сообщение из строки Str. Формат строки - цифровой поток
    function FromString(Str: AnsiString): Boolean;
    /// Возвращает сообщение в виде строки. Формат строки - цифровой поток
    function ToString(): AnsiString; reintroduce;
    /// Заполняет секцию параметров из строки, разделенной символами "|"
    function ParseInfo(Str: string): Boolean;
    /// Проверяет наличие адреса в синбаях
    function HaveSeenBy(Addr: TAddr): Boolean;
    /// Добавляет адрес в синбаи
    function AddSeenBy(Addr: TAddr): Boolean;
  end;


  { TDnmpMsgQueue }
  // { TODO: Сделать своп сообщений на диск }
  TDnmpMsgQueue = class(TObjectList)
  private
    function GetMsg(Index: Integer): TDnmpMsg;
    procedure SetMsg(Index: Integer; Value: TDnmpMsg);
  public
    property Items[Index: Integer]: TDnmpMsg read GetMsg write SetMsg; default;
    function GetMsgByAddr(FAddr: TAddr): TDnmpMsg;
    function ToStorage(): TDataStorage;
    function FromStorage(Storage: TDataStorage): Boolean;
    procedure SaveToFile(Filename: string);
    function LoadFromFile(Filename: string): Boolean;
  end;


  TDnmpContactState = (asUnknown, asOnline, asOffline, asBusy);
  TDnmpContactInfoType = (ctBrief, ctPublic, ctPrivate, ctAll);
  TDnmpLinkType = (ltTemporary, ltListener, ltIncoming, ltOutcoming);


  { Generic contact info }
  TDnmpContactInfo = class(TCollectionItem)
  public
    { item name }
    Name: string;
    { item value }
    Value: AnsiString;
    { item value type (stUnknown, stString, stInteger, stNumber, stList, stDictionary) }
    ValueType: TDataStorageType;
    { info type (ctPublic, ctPrivate) }
    InfoType: TDnmpContactInfoType;
    { parent item name }
    ParentName: string;
  end;

  TDnmpPassport = class;

  { TDnmpContact }

  TDnmpContact = class(TInterfacedObject)
  private
    FInfoList: TCollection;
    function FGetInfo(AName: string): string;
    procedure FSetInfo(AName: string; AValue: string);
  public
    { === Brief info === }
    { Contact name }
    Name: string;
    { point address }
    Addr: TAddr;
    { GUID assigned when contact approved by node }
    GUID: string;
    { Contact state }
    State: TDnmpContactState;  // asUnknown, asOnline, asOffline, asBusy
    { === Public info === }
    { GUID of node, that approved this contact }
    SeniorGUID: string;
    { Status message }
    StatusMessage: string;
    { Avatar picture }
    Picture: AnsiString;
    { Rating }
    Rating: integer;
    { === Private info === }
    { Owner info (name, organization, etc) }
    Owner: string;
    { Location info (address, region) }
    Location: string;
    { IP address (optional) }
    IpAddr: string;
    { Phone number (optional) }
    PhoneNo: string;
    { Any other info}
    OtherInfo: string;
    { Private key }
    Key: AnsiString;
    { === Extra info === }
    // Assigned only for points
    Passport: TDnmpPassport;
    IncomingChat: Boolean; // has unread incoming CHAT message or invite
    IncomingFile: Boolean; // has unread incoming file
    IsNode: Boolean;
    { Online state }
    //Online: Boolean;
    { ltPoint, ltNode, ltTemporary }
    //LinkType: TDnmpLinkType;
    constructor Create();
    destructor Destroy(); override;
    property Info[AName: string]: string read FGetInfo write FSetInfo;
    { additional data count }
    function InfoCount(): integer;
    { additional info name by index }
    function GetInfoName(Index: integer): string;
    { additional info value by index }
    function GetInfo(Index: integer): string;
    { address string }
    function AddrStr(): string;
    function SameAddr(AAddr: TAddr): Boolean;
    function ToStorage(InfoType: TDnmpContactInfoType): TDataStorage;
    function FromStorage(Storage: TDataStorage): Boolean;
    function StateStr(): string;
    function StateFromStr(s: string): Boolean;
    // Assign data from Item
    procedure Assign(Item: TDnmpContact); virtual;
    // Update data from Item
    procedure UpdateFrom(Item: TDnmpContact); virtual;
  end;

  { TDnmpContactList }

  TDnmpContactList = class(TInterfacedObject)
  private
    FObjectList: TObjectList;
    function GetItem(Index: Integer): TDnmpContact;
    procedure SetItem(Index: Integer; Value: TDnmpContact);
    function FGetCount(): Integer;
  public
    ParentList: TDnmpContactList;
    Filename: string;
    constructor Create(AParentList: TDnmpContactList); reintroduce;
    destructor Destroy(); override;
    property Items[Index: Integer]: TDnmpContact read GetItem write SetItem; default;
    property Count: Integer read FGetCount;
    // Search only in this list
    function GetByAddr(AAddr: TAddr): TDnmpContact;
    // Search only in this list
    function GetByGUID(sGUID: string): TDnmpContact;
    // Add in this list and parent list
    procedure AddItem(Item: TDnmpContact); virtual;
    function AddByGUID(sGUID: string): TDnmpContact;
    function DelByGUID(sGUID: string): TDnmpContact;
    { Find item by GUID or Addr, if found then update, if not found then add }
    function UpdateItem(Addr: TAddr; sGUID, sSeniorGUID, sName, sState, sStatus: string): TDnmpContact; overload;
    { Find item by GUID or Addr, if found then update, if not found then add
      Items with addr 0.0 and empty GUID not compared
      If item not found in this list, search in parent list }
    function UpdateItem(Item: TDnmpContact): TDnmpContact; overload;
    // remove item from this list, not affected to parent
    function Extract(Item: TDnmpContact): Boolean; virtual;
    // clear all items in this list, parent not affected
    procedure Clear();
    // return True if this list have specified Item
    function HaveItem(Item: TDnmpContact): Boolean;
    function ToStorage(InfoType: TDnmpContactInfoType): TDataStorage; virtual;
    function FromStorage(Storage: TDataStorage): Boolean; virtual;
  end;

  { TDnmpPassport }

  TDnmpPassport = class(TInterfacedObject)
  public
    { Owner contact }
    Contact: TDnmpContact;
    { Owner contact GUID }
    ContactGUID: string;
    { Owner favorites contacts (parented to Mgr.ContactList) }
    FavoriteContactsList: TDnmpContactList;
    { Subscribed services names }
    ServicesList: TStringList;
    // incoming messages box (to this contact)
    MsgInbox: TDnmpMsgQueue;
    // outcoming messages box (from this contact)
    MsgOutbox: TDnmpMsgQueue;
    constructor Create(AContact: TDnmpContact; AParentContactsList: TDnmpContactList);
    destructor Destroy; override;
    function ToStorage(): TDataStorage;
    function FromStorage(Storage: TDataStorage): Boolean;
  end;

  { TDnmpPassportList }

  TDnmpPassportList = class(TInterfacedObject)
  private
    FPassportList: TObjectList;
    function GetPassport(Index: Integer): TDnmpPassport;
    procedure SetPassport(Index: Integer; Value: TDnmpPassport);
    function FGetPassportCount(): Integer;
  public
    ParentList: TDnmpContactList;
    Filename: string;
    constructor Create(AParentContactsList: TDnmpContactList);
    destructor Destroy; override;
    // Passport items list
    property Items[Index: Integer]: TDnmpPassport read GetPassport write SetPassport;
    // Number of passport items
    property Count: Integer read FGetPassportCount;
    // Add passport in this list
    procedure AddPassport(Item: TDnmpPassport);
    // remove item from this list, not affected to parent
    function Extract(Item: TDnmpPassport): Boolean;
    function ToStorage(InfoType: TDnmpContactInfoType): TDataStorage;
    function FromStorage(Storage: TDataStorage): Boolean;

  end;

  TNodeList = class(TDnmpContactList);

  { TPointList }

  TPointList = class(TDnmpContactList)
  private
    FPassportList: TDnmpPassportList;
  public
    constructor Create(AParentContactsList: TDnmpContactList);
    destructor Destroy; override;
    property PassportList: TDnmpPassportList read FPassportList write FPassportList;
    // Add contact in this list and parent list
    procedure AddItem(Item: TDnmpContact); override;
    // remove item from this list, not affected to parent
    function Extract(Item: TDnmpContact): Boolean; override;
    function ToStorage(InfoType: TDnmpContactInfoType): TDataStorage; override;
    function FromStorage(Storage: TDataStorage): Boolean; override;
  end;

  TIncomingMsgEvent = procedure(Sender: TObject; Msg: TDnmpMsg) of object;

  // Базовый класс линка
  { TODO : Очередь сообщений из паспорта контакта }
  TDnmpLink = class(TInterfacedObject)
  protected
    FOnIncomingMsg: TIncomingMsgEvent;
    FOnConnect: TNotifyEvent;
    FOnDisconnect: TNotifyEvent;
    FActive: Boolean;
  public
    Mgr: TDnmpManager;
    // my info from Mgr
    MyInfo: TDnmpContact;
    // remote side info
    RemoteInfo: TDnmpContact;
    // link type, default ltTemporary
    LinkType: TDnmpLinkType;
    Speed: Integer;
    // nodes under this remote contact
    NodesUnder: TNodeList;

    // link-specific incoming message handler
    MsgHandler: TDnmpMsgHandler;

    constructor Create(AMgr: TDnmpManager; ARemoteInfo: TDnmpContact = nil); virtual;
    destructor Destroy(); override;
    // Установить соединение
    function Connect(): Boolean; virtual;
    // Разорвать соединение
    function Disconnect(): Boolean; virtual;
    // Принимать входящие подключения
    function Listen(): Boolean; virtual;
    // Проверить соединение. Возвращает FALSE, если соединение невозможно восстановить
    function Check(): Boolean; virtual;
    // Отправить сообщение через этот линк
    function SendMsg(Msg: TDnmpMsg): Boolean; virtual;
    // Утвердить линк, принять его в сеть
    function Approve(): Boolean;
    { True when link connected or listening }
    property Active: Boolean read FActive;
    { Triggers when link received incoming message }
    property OnIncomingMsg: TIncomingMsgEvent read FOnIncomingMsg write FOnIncomingMsg;
    { Triggers after successful connection (but before authorization) }
    property OnConnect: TNotifyEvent read FOnConnect write FOnConnect;
    { Triggers after disconnection }
    property OnDisconnect: TNotifyEvent read FOnDisconnect write FOnDisconnect;
  end;

  { TDnmpLinkList }

  TDnmpLinkList = class(TObjectList)
  private
    function GetLink(Index: Integer): TDnmpLink;
    procedure SetLink(Index: Integer; Value: TDnmpLink);
  public
    property Items[Index: Integer]: TDnmpLink read GetLink write SetLink; default;
    function GetLinkByAddr(FAddr: TAddr): TDnmpLink;
    procedure RemoveInactive();
  end;

  TIncomingLinkEvent = procedure(Sender: TObject; Link: TDnmpLink) of object;

  // Запись таблицы маршрутизации
  TDnmpRoutingTableRecord = record
    DestNodeID: TNodeID; // Узел назначения
    GateNodeID: TNodeID; // Соседний узел, за которым прячется узел назначения
    TraceID: Cardinal;   // Таймштамп трассировки
  end;

  TDnmpRoutingTableRecordArray = array of TDnmpRoutingTableRecord;

  { TDnmpRoutingTable }
  // Таблица маршрутизации сервера
  TDnmpRoutingTable = class(TObject)
  private
    FItems: TDnmpRoutingTableRecordArray;
    FCount: Integer;
    function FGetGateForDest(DestID: TNodeID; var GateID: TNodeID): Boolean;
  public
    Links: TDnmpLinkList;
    constructor Create(ALinks: TDnmpLinkList);
    destructor Destroy; override;
    property Items: TDnmpRoutingTableRecordArray read FItems;
    property Count: Integer read FCount;
    // Определяет линк для заданного адреса
    function LinkForDestAddr(Addr: TAddr): TDnmpLink;
    // Добавляет запись таблицы маршрутизации
    procedure AddItem(GateID, DestID: TNodeID; TraceID: Cardinal);
    // Добавляет записи таблицы маршрутизации из синбаев
    procedure AddRountingItems(GateID: TNodeID; TraceID: Cardinal; SeenBy: TSeenBy);
    // Удаляет все записи с указанным GateID
    procedure DelGate(GateID: TNodeID);
    // Удаляет запись с указанным DestID
    procedure DelDest(DestID: TNodeID);
    // Удаляет все записи
    procedure Clear();
    { save to storage }
    function ToStorage(): TDataStorage;
    function FromStorage(Storage: TDataStorage): Boolean;
  end;

  { TDnmpMsgHandler }
  { Базовый класс обработчика входящих сообщений
    Если при вызове Create указан Link, то сервис привязывается к данному линку }
  // links, services
  TDnmpMsgHandler = class(TObject)
  protected
    FMgr: TDnmpManager;
    FLink: TDnmpLink;
    {MsgTypes: TDnmpMsgTypes; }
  public
    property Mgr: TDnmpManager read FMgr;
    // for links only
    property Link: TDnmpLink read FLink;
    { Add self to Mgr.MsgHandlers }
    constructor Create(AMgr: TDnmpManager; ALink: TDnmpLink = nil); virtual;
    { Remove self from Mgr.MsgHandlers }
    destructor Destroy(); override;
    // Init and start handler
    function Start(): Boolean; virtual;
    // Stop and flush handler
    function Stop(): Boolean; virtual;
    { Обработка команды (Thread-safe) от указанного адреса }
    function Cmd(Text: string; Addr: TAddr): string; virtual;
    // Разбор сообщения и выполнение требуемых действий
    // Возвращает True если сообщение обработано и дальнейшая обработка не требуется
    function ParseMsg(AMsg: TDnmpMsg): Boolean; virtual; abstract;
  end;

  TLogEvent = procedure(Sender: TObject; LogMsg: string) of object;
  TMgrEvent = procedure(Sender, AText: string) of object;


  { TDnmpManager }
  { DNMP Manager (messenger, mailer)
    Maintain contacts, links, messages queues, routing tables, messages handlers
  }
  TDnmpManager = class(TObject)
  private
    FOnLog: TLogEvent;
    FOnCmd: TLogEvent;
    FOnEvent: TMgrEvent;
    FOnIncomingMsg: TIncomingMsgEvent;
    FServerMode: Boolean;
    CmdQueue: TStringList;
    FUplink: TDnmpLink;
    FListenerLink: TDnmpLink;
    procedure FSetUplink(Value: TDnmpLink);
    procedure FSetListenerLink(Value: TDnmpLink);
    function FActive(): Boolean;
    { Commands handler:
    AUTH_OK - someone succesfully authorised
    EVENT <sender> <text> - internal event
    ASK <addr> <msg_type> <msg_info> - send request for some info (???)
    APPROVE <GUID> - approve link
    GET_INFO <addr> - send info request to specified address
    GET_POINTLIST <addr> - send pointlist request to specified address
    ROUTE VIA <gate_id> <node_id> [node2_id] ..
      Add routes to specified nodes via 'gate'
      Добавляет маршруты на указанные узлы через узел gate.
      Если на узел уже есть маршрут, то он будет заменен
    ROUTE DEL <node_id>|ALL [node2_id] ...
      Удаляет маршруты на указанные узлы
    }
    function CmdHandler(CmdText: string): string;
    // срабатывает когда нет ни одного активного линка
    procedure OnAllDisconnected();
  public
    // Serializer for objects
    Serializer: TDataSerializer;
    MyPassport: TDnmpPassport;
    MyInfo: TDnmpContact;
    // Global contact list
    ContactList: TDnmpContactList;
    // Owned passports list
    PassportList: TDnmpPassportList;
    // Known linkable nodes, parented to ContactList
    NodeList: TNodeList;
    // Owned points (Server only), parented to ContactList
    PointList: TPointList;
    // Unapproved links (Server only), not parented to ContactList
    UnapprovedList: TDnmpContactList;
    // Temporary contacts (from contacts search requests)
    // not parented to global contacts
    TmpContactList: TDnmpContactList;
    // Active links
    LinkList: TDnmpLinkList;
    // Outgoing messages queue
    MsgQueue: TDnmpMsgQueue;
    // Config
    Conf: TDnmpConf;
    RoutingTable: TDnmpRoutingTable;
    // Incoming messages handlers
    MsgHandlers: TObjectList;
    { Path to data files }
    sDataPath: string;
    // Default uplink
    property Uplink: TDnmpLink read FUplink write FSetUplink;
    // Listener (Server only)
    property ListenerLink: TDnmpLink read FListenerLink write FSetListenerLink;
    property Active: Boolean read FActive;
    { True if incoming connections allowed }
    property ServerMode: Boolean read FServerMode;

    constructor Create(ConfName: string);
    destructor Destroy(); override;
    // Reset all data to default, load data from storage
    procedure Init();
    // wrapper, load list from default file.
    // For TDnmpContactList and TDnmpPassportList
    procedure LoadList(List: TObject);
    // wrapper, save list to default file.
    // For TDnmpContactList and TDnmpPassportList
    procedure WriteList(List: TObject; AInfoType: TDnmpContactInfoType);
    // Load all data from storage
    procedure LoadFromFile();
    // Save all data to storage
    procedure SaveToFile();
    // ==== Base functions
    // Send message, autodetect link for sending
    // if Msg.TargetAddr = EmptyAddr then send to all nodes links
    function SendMsg(Msg: TDnmpMsg): Boolean;
    // Create and send message with given data
    procedure SendDataMsg(DestAddr: TAddr; MsgType, Info, Text: string);
    // Create and send error reply message
    procedure SendErrorMsg(DestAddr: TAddr; ErrCode, ErrText: string);
    // Send message to multiple destinations
    // all - to all points and nodes
    // points - to all points
    // nodes - to all nodes
    function SendBroadcastMsg(Msg: TDnmpMsg; Destinations: string): Boolean;
    procedure Start();
    procedure Stop();
    procedure StartServer();
    procedure StartClient();
    { Initiate connection to specified node }
    procedure StartNodeConnection(NodeInfo: TDnmpContact);
    { Disconnect from specified node }
    procedure StopNodeConnection(NodeInfo: TDnmpContact);
    { Log messages }
    property OnLog: TLogEvent read FOnLog write FOnLog;
    property OnCmd: TLogEvent read FOnCmd write FOnCmd;
    property OnEvent: TMgrEvent read FOnEvent write FOnEvent;
    property OnIncomingMsg: TIncomingMsgEvent read FOnIncomingMsg write FOnIncomingMsg;
    { Handler for OnIncomingMsg from links, process incoming Msg to MsgHandlers }
    procedure IncomingMsgHandler(Sender: TObject; Msg: TDnmpMsg);
    // Triggers OnLog
    procedure DebugText(s: string);
    // Triggers OnLog, show Msg and Link (optional) details
    procedure DebugMsg(Msg: TDnmpMsg; Link: TDnmpLink = nil; Comment: string = '');
    // Execute text command, triggers OnCmd
    function Cmd(CmdText: string): string;
    { Internal event, triggers OnEvent
    MGR
      REFRESH
      APPROVE
      UPDATE
        ROUTING
        CONTACTS
        TMP_CONTACTS
        POINTLIST
        NODELIST
        LINKS
    }
    procedure Event(Sender, Text: string);
    // Add text command to commands queue
    procedure AddCmd(CmdText: string);
    // Execute text command from commands queue
    procedure Tick();
    { Add link to link list, create and attach AUTH handler to link }
    function AddLink(Link: TDnmpLink): integer;
    { Remove link from links list }
    function DelLink(Link: TDnmpLink): Boolean;
    { Approve specified link
    if link is Point: assign new point number, add to pointlist
    if link is Node:
    - check node info, check connection to node
    - assign new node number, add to nodelist
    - send info to other nodes
    }
    function Approve(ALinkInfo: TDnmpContact): Boolean;
    // Return maximum point ID +1
    function GetFreePointID(): TPointID;
    // Return maximum node ID +1
    function GetFreeNodeID(): TNodeID;
    // De-serialize data from message body to storage
    function MsgDataToStorage(Msg: TDnmpMsg): TDataStorage;
    // ==== Сервисные функции
    function GetContactByAddr(SomeAddr: TAddr): TDnmpContact;
    function GetContactByGUID(SomeGUID: string): TDnmpContact;
    // запрос информации об указанном адресе
    procedure RequestInfoByAddr(Addr: TAddr);
    // запрос поинтлиста с указанного адреса
    procedure RequestPointlist(Addr: TAddr);
    // запрос (поиск) контактов по имени
    procedure RequestContactsByName(AName: string);
    // ==== Приемники событий от модулей
    // когда контакт успешно подключился к нам
    procedure ContactConnectedIn(AContact: TDnmpContact);
    // когда мы успешно подключились к контакту
    procedure ContactConnectedOut(AContact: TDnmpContact);
  end;

  // Return addr 0.0
  function EmptyAddr(): TAddr;
  // Return True if Addr=0.0
  function IsEmptyAddr(Addr: TAddr): Boolean;
  // Return node addr from given addr: 1.2 -> 1.0
  function NodeAddr(Addr: TAddr): TAddr;
  function AddrToStr(Addr: TAddr): string;
  function StrToAddr(StrAddr: string): TAddr;
  // Return True, if given addresses equal
  function SameAddr(Addr1, Addr2: TAddr): Boolean;
  // Return True, if given addresses have equal nodes
  function SameNode(Addr1, Addr2: TAddr): Boolean;
  // Return link type as string
  function LinkTypeToStr(lt: TDnmpLinkType): string;
  function StrToLinkType(s: string): TDnmpLinkType;

  // Convert TDateTime timestamp to string
  function TimestampToStr(dt: TDateTime): string;
  // Convert string to TDateTime timestamp
  function StrToTimestamp(s: string): TDateTime;

  // convert Stream to AnsiString
  function StreamToStr(AStream: TStream): AnsiString;
  // convert AnsiString to Stream
  function StrToStream(s: AnsiString; AStream: TStream): Boolean;

  /// Save string to file with given Filename
  /// Return True on succes
  function StrToFile(FileName, Str: AnsiString): Boolean;
  /// Read string from file with given Filename
  /// Return empty string "" on failure
  function FileToStr(FileName: string): AnsiString;

  // simple key generator
  // {TODO: full random long key}
  function GenerateKey(): AnsiString;
  function GenerateGUID(): string;
  function GenerateTemporaryGUID(): string;
  function IsTemporaryGUID(sGUID: string): Boolean;
  // Extract and return first word from string
  function ExtractFirstWord(var s: string; delimiter: string = ' '): string;
  // Проверяет заданный путь. Создает каталоги, если их нет
  function CheckPath(sPath: string): Boolean;


const
  csConfigFileName = 'settings.ini';
  csMyInfoFileName = 'MyInfo';
  csMyPassportFileName = 'MyPassport';
  csPointlistFileName = 'PointList';
  csNodelistFileName = 'NodeList';
  csUnapprovedFileName = 'UnapprovedList';
  csContactListFileName = 'ContactList';
  csPassportListFileName = 'PassportList';
  csMsgQueueFileName = 'MsgQueue';
  ciKeyLength = 8;
  CRLF = #13#10;

var
  sDnmpDataDir: string = 'data';
  // next msg serial number (global)
  iMsgSerialNum: integer = 0;

implementation
uses RC4, dnmp_ip, dnmp_info, dnmp_auth;

// === Functions ===
function EmptyAddr(): TAddr;
begin
  Result.Node:=0;
  Result.Point:=0;
end;

function IsEmptyAddr(Addr: TAddr): Boolean;
begin
  Result:=((Addr.Node=0) and (Addr.Point=0));
end;

function NodeAddr(Addr: TAddr): TAddr;
begin
  Result.Node:=Addr.Node;
  Result.Point:=0;
end;

function AddrToStr(Addr: TAddr): string;
begin
  Result:=''+IntToStr(Addr.Node)+'.'+IntToStr(Addr.Point);
end;

function StrToAddr(StrAddr: string): TAddr;
var
  i: integer;
begin
  i:=Pos('.', StrAddr);
  Result.Node:=StrToIntDef(Copy(StrAddr, 1, i-1), 0);
  Result.Point:=StrToIntDef(Copy(StrAddr, i+1, maxint), 0);
end;

function SameAddr(Addr1, Addr2: TAddr): Boolean;
begin
  Result:=((Addr1.Node=Addr2.Node) and (Addr1.Point=Addr2.Point));
end;

function SameNode(Addr1, Addr2: TAddr): Boolean;
begin
  Result:=(Addr1.Node=Addr2.Node);
end;

function LinkTypeToStr(lt: TDnmpLinkType): string;
begin
  result:='';
  case lt of
    ltTemporary: Result:='temp';
    ltListener: Result:='listen';
    ltIncoming: Result:='in';
    ltOutcoming: Result:='out';
  end;
end;

function StrToLinkType(s: string): TDnmpLinkType;
begin
  Result:=ltTemporary;
  if s='temp' then Result:=ltTemporary
  else if s='listen' then Result:=ltListener
  else if s='in' then Result:=ltIncoming
  else if s='out' then Result:=ltOutcoming;
end;

function TimestampToStr(dt: TDateTime): string;
begin
  // Filesystem timestamp
  Result:=IntToStr(DateTimeToFileDate(dt));

  // ISO 8601
  //Result:=FormatDateTime('YYYY-MM-DD"T"HH:NN:SS', dt);
end;

function StrToTimestamp(s: string): TDateTime;
begin
  // Filesystem timestamp
  Result:=FileDateToDateTime(StrToIntDef(s, 0));

  // ISO 8601
  { TODO : standart timestamp }
end;

function StreamToStr(AStream: TStream): AnsiString;
var
  ss: TStringStream;
begin
  Result:='';
  ss:=TStringStream.Create('');
  try
    AStream.Seek(0, soFromBeginning);
    ss.CopyFrom(AStream, AStream.Size);
    Result:=ss.DataString;
  finally
    ss.Free();
  end;
end;

function StrToStream(s: AnsiString; AStream: TStream): Boolean;
var
  ss: TStringStream;
begin
  ss:=TStringStream.Create(s);
  try
    ss.Seek(0, soFromBeginning);
    AStream.Seek(0, soFromBeginning);
    AStream.CopyFrom(ss, ss.Size);
    Result:=True;
  finally
    ss.Free();
  end;
end;

function StrToFile(FileName, Str: AnsiString): Boolean;
var
  fs: TFileStream;
begin
  Result:=False;
  try
    fs:=TFileStream.Create(FileName, fmCreate);
  except
    fs:=nil;
  end;

  if not Assigned(fs) then Exit;
  try
    StrToStream(Str, fs);
    Result:=True;
  finally
    FreeAndNil(fs);
  end;
end;

function FileToStr(FileName: string): AnsiString;
var
  fs: TFileStream;
begin
  Result:='';
  if not FileExists(FileName) then Exit;
  try
    fs:=TFileStream.Create(FileName, fmOpenRead);
  except
    fs:=nil;
  end;

  if not Assigned(fs) then Exit;
  try
    Result:=StreamToStr(fs);
  finally
    fs.Free();
  end;
end;

function GenerateKey(): AnsiString;
var
  sDict: string;
  i, l: Integer;
begin
  sDict:='qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890';
  l:=Length(sDict);
  Result:='';
  Randomize();
  for i:=1 to ciKeyLength do Result:=Result+Copy(sDict, Random(l)+1, 1);
end;

function GenerateGUID(): string;
var
  NewGuid: TGuid;
begin
  Result:='';
  if CreateGUID(NewGuid)=0 then Result:=GUIDToString(NewGuid);
end;

function GenerateTemporaryGUID(): string;
var
  NewGuid: TGuid;
begin
  Result:='';
  if CreateGUID(NewGuid)=0 then
  begin
    NewGuid.D1:=0;
    Result:=GUIDToString(NewGuid);
  end;
end;

function IsTemporaryGUID(sGUID: string): Boolean;
var
  TmpGuid: TGuid;
begin
  Result:=True;
  if TryStringToGUID(sGUID, TmpGuid) then Result:=(TmpGuid.D1=0);
end;

function ExtractFirstWord(var s: string; delimiter: string = ' '): string;
var
  i: integer;
begin
  Result:='';
  i:=Pos(delimiter, s);
  if i>0 then
  begin
    Result:=Copy(s, 1, i-1);
    s:=Copy(s, i+1, maxint);
  end
  else
  begin
    Result:=s;
    s:='';
  end;
end;

// Проверяет заданный путь. Создает каталоги, если их нет
function CheckPath(sPath: string): Boolean;
begin
  Result:=True;
  if (not DirectoryExists(sPath)) then
  begin
    if (not CreateDir(sPath)) then Result:=False;
  end;
end;

{ TDnmpPassportList }

function TDnmpPassportList.GetPassport(Index: Integer): TDnmpPassport;
begin
  Result:=(FPassportList.Items[Index] as TDnmpPassport);
end;

procedure TDnmpPassportList.SetPassport(Index: Integer; Value: TDnmpPassport);
begin
  FPassportList.Items[Index]:=Value;
end;

function TDnmpPassportList.FGetPassportCount(): Integer;
begin
  Result:=FPassportList.Count;
end;

constructor TDnmpPassportList.Create(AParentContactsList: TDnmpContactList);
begin
  inherited Create();
  ParentList:=AParentContactsList;
  FPassportList:=TObjectList.Create(False);
end;

destructor TDnmpPassportList.Destroy();
begin
  FreeAndNil(FPassportList);
  inherited Destroy;
end;

procedure TDnmpPassportList.AddPassport(Item: TDnmpPassport);
var
  i: integer;
  TmpPassport: TDnmpPassport;
begin
  if not Assigned(Item) then Exit;

  for i:=0 to Count-1 do
  begin
    TmpPassport:=Items[i];
    if TmpPassport.Contact.GUID=Item.Contact.GUID then
    begin
      // такой паспорт уже есть
      Exit;
    end;
  end;
  // добавляем недостающий паспорт
  FPassportList.Add(Item);
end;

function TDnmpPassportList.Extract(Item: TDnmpPassport): Boolean;
begin
  Result:=Assigned(FPassportList.Extract(Item));
end;

function TDnmpPassportList.ToStorage(InfoType: TDnmpContactInfoType
  ): TDataStorage;
var
  Storage: TDataStorage;
  i: Integer;
begin
  Storage:=TDataStorage.Create(stDictionary);
  for i:=0 to Self.Count-1 do
  begin
    Storage.Add(IntToStr(i), Self.Items[i].ToStorage());
  end;

  Result:=TDataStorage.Create(stDictionary);
  Result.Add('type', 'DnmpPassportList');
  Result.Add('items', Storage);
end;

function TDnmpPassportList.FromStorage(Storage: TDataStorage): Boolean;
var
  SubStorage: TDataStorage;
  i: Integer;
  Item: TDnmpPassport;
begin
  Result:=False;
  if not Assigned(Storage) then Exit;
  if Storage.StorageType <> stDictionary then Exit;
  if Storage.GetString('type')<>'DnmpPassportList' then Exit;
  SubStorage:=Storage.GetObject('items');
  if SubStorage.StorageType <> stDictionary then Exit;
  for i:=0 to SubStorage.Count-1 do
  begin
    Item:=TDnmpPassport.Create(nil, ParentList);
    if not Item.FromStorage(SubStorage.GetObject(i)) then
    begin
      Item.Free();
      Continue;
    end;
    Self.AddPassport(Item);
  end;
  Result:=True;

  // passports lodaed with empty contacts, only ContactGUID filled
  // set contacts to passports from ParentList
  if not Assigned(ParentList) then Exit;
  for i:=0 to Self.Count-1 do
  begin
    Item:=Self.Items[i];
    Item.Contact:=ParentList.GetByGUID(Item.ContactGUID);
  end;
end;

{ TPointList }

constructor TPointList.Create(AParentContactsList: TDnmpContactList);
begin
  inherited Create(AParentContactsList);
end;

destructor TPointList.Destroy();
begin
  inherited Destroy;
end;

procedure TPointList.AddItem(Item: TDnmpContact);
begin
  inherited AddItem(Item);
  // после добавления контакта проверяем наличие паспорта и добавляем при
  // необходимости
  if not Assigned(Item.Passport) then
  begin
    Item.Passport:=TDnmpPassport.Create(Item, ParentList);
  end;

  if Assigned(FPassportList) then FPassportList.AddPassport(Item.Passport);
end;

function TPointList.Extract(Item: TDnmpContact): Boolean;
begin
  Result:=inherited Extract(Item);
  // убираем паспорт
  if Assigned(FPassportList) then FPassportList.Extract(Item.Passport);
end;

function TPointList.ToStorage(InfoType: TDnmpContactInfoType): TDataStorage;
begin
  Result:=inherited ToStorage(InfoType);
end;

function TPointList.FromStorage(Storage: TDataStorage): Boolean;
begin
  Result:=inherited FromStorage(Storage);
end;

{ TDnmpPassport }

constructor TDnmpPassport.Create(AContact: TDnmpContact;
  AParentContactsList: TDnmpContactList);
begin
  inherited Create();
  Contact:=AContact;
  FavoriteContactsList:=TDnmpContactList.Create(AParentContactsList);
  ServicesList:=TStringList.Create();
  MsgInbox:=TDnmpMsgQueue.Create();
  MsgOutbox:=TDnmpMsgQueue.Create();
end;

destructor TDnmpPassport.Destroy();
begin
  FreeAndNil(MsgOutbox);
  FreeAndNil(MsgInbox);
  FreeAndNil(ServicesList);
  FreeAndNil(FavoriteContactsList);
  inherited Destroy;
end;

function TDnmpPassport.ToStorage(): TDataStorage;
begin
  Result:=TDataStorage.Create(stDictionary);
  Result.Add('type', 'DnmpPassport');
  Result.Add('contact_guid', Self.Contact.GUID);
  //Result.Add('contact', Self.Contact.ToStorage(ctAll));
  Result.Add('contacts_list', Self.FavoriteContactsList.ToStorage(ctBrief));
  //Result.Add('services_list', Self.ServicesList.ToStorage(ctBrief));
  Result.Add('msg_inbox', Self.MsgInbox.ToStorage());
  Result.Add('msg_outbox', Self.MsgOutbox.ToStorage());
end;

function TDnmpPassport.FromStorage(Storage: TDataStorage): Boolean;
var
  SubStorage: TDataStorage;
begin
  Result:=False;
  if not Assigned(Storage) then Exit;
  if Storage.StorageType <> stDictionary then Exit;
  if Storage.GetString('type')<>'DnmpPassport' then Exit;

  ContactGUID:=Storage.GetString('contact_guid');

  {
  // Contact
  SubStorage:=Storage.GetObject('contact');
  if Assigned(SubStorage) then Self.Contact.FromStorage(SubStorage);
  //if Assigned(SubStorage) then SubStorage.Free();
  }

  // FavoriteContactsList
  SubStorage:=Storage.GetObject('contacts_list');
  if Assigned(SubStorage) then Self.FavoriteContactsList.FromStorage(SubStorage);
  //if Assigned(SubStorage) then SubStorage.Free();

  {
  // ServicesList
  SubStorage:=Storage.GetObject('services_list');
  if Assigned(SubStorage) then Self.ServicesList.FromStorage(SubStorage);
  //if Assigned(SubStorage) then SubStorage.Free();
  }

  // MsgInbox
  SubStorage:=Storage.GetObject('msg_inbox');
  if Assigned(SubStorage) then Self.MsgInbox.FromStorage(SubStorage);
  //if Assigned(SubStorage) then SubStorage.Free();

  // MsgOutbox
  SubStorage:=Storage.GetObject('msg_outbox');
  if Assigned(SubStorage) then Self.MsgOutbox.FromStorage(SubStorage);
  //if Assigned(SubStorage) then SubStorage.Free();

  Result:=True;
end;

{ TDnmpContactList }

function TDnmpContactList.GetItem(Index: Integer): TDnmpContact;
begin
  Result:=TDnmpContact(FObjectList.Items[index]);
end;

procedure TDnmpContactList.SetItem(Index: Integer; Value: TDnmpContact);
begin
  FObjectList.Items[Index]:=Value;
end;

function TDnmpContactList.FGetCount(): Integer;
begin
  Result:=FObjectList.Count;
end;

constructor TDnmpContactList.Create(AParentList: TDnmpContactList);
begin
  inherited Create();
  FObjectList:=TObjectList.Create(False);
  ParentList:=AParentList;
end;

destructor TDnmpContactList.Destroy();
begin
  FreeAndNil(FObjectList);
  inherited Destroy();
end;

function TDnmpContactList.GetByAddr(AAddr: TAddr): TDnmpContact;
var
  i: Integer;
begin
  // Search only in this list
  for i:=0 to Count-1 do
  begin
    Result:=Items[i];
    if SameAddr(Result.Addr, AAddr) then Exit;
  end;
  Result:=nil;
end;

function TDnmpContactList.GetByGUID(sGUID: string): TDnmpContact;
var
  i: Integer;
begin
  // Search only in this list
  for i:=0 to Count-1 do
  begin
    Result:=Items[i];
    if Result.GUID=sGUID then Exit;
  end;
  Result:=nil;
end;

procedure TDnmpContactList.AddItem(Item: TDnmpContact);
begin
  if Assigned(ParentList) then
  begin
    if not ParentList.HaveItem(Item) then ParentList.AddItem(Item);
  end;
  if FObjectList.IndexOf(Item)=-1 then FObjectList.Add(Item);
end;

function TDnmpContactList.AddByGUID(sGUID: string): TDnmpContact;
begin
  Result:=nil;
  if Trim(sGuid)='' then Exit;
  // Search in this list and parent list
  Result:=GetByGUID(sGUID);
  if Assigned(Result) then Exit;

  if Assigned(ParentList) then Result:=ParentList.GetByGUID(sGUID);
  if not Assigned(Result) then
  begin
    Result:=TDnmpContact.Create();
    Result.GUID:=sGUID;
    if Assigned(ParentList) then ParentList.AddItem(Result);
  end;
  FObjectList.Add(Result);
end;

function TDnmpContactList.DelByGUID(sGUID: string): TDnmpContact;
begin
  Result:=GetByGUID(sGUID);
  if Assigned(Result) then
  begin
    FObjectList.Extract(Result);
  end;
end;

function TDnmpContactList.UpdateItem(Addr: TAddr; sGUID, sSeniorGUID, sName,
  sState, sStatus: string): TDnmpContact;
begin
  Result:=GetByGUID(sGUID);
  if not Assigned(Result) then
  begin
    // Not found in this list, look in parent list
    if Assigned(ParentList) then Result:=ParentList.GetByGUID(sGUID);
    if Assigned(Result) then Self.AddItem(Result);
  end;

  if not Assigned(Result) then
  begin
    // Contact not found anywhere, create new
    Result:=TDnmpContact.Create();
    Result.GUID:=sGUID;
    Self.AddItem(Result);
  end;
  Result.SeniorGUID:=sSeniorGUID;
  Result.Name:=sName;
  Result.Addr:=Addr;
  Result.StateFromStr(sState);
  Result.StatusMessage:=sStatus;
end;

function TDnmpContactList.UpdateItem(Item: TDnmpContact): TDnmpContact;
begin
  Result:=nil;
  if Trim(Item.GUID)<>'' then Result:=Self.GetByGUID(Item.GUID);
  if not Assigned(Result) then
  begin
    // Not found in this list, look in parent list
    if Assigned(ParentList) then
    begin
      if Trim(Item.GUID)<>'' then Result:=ParentList.GetByGUID(Item.GUID);
      if Assigned(Result) then
      begin
        Self.AddItem(Result);
      end;
    end;
  end;

  if not Assigned(Result) then
  begin
    // Contact not found anywhere (fishy!)
    Result:=Item;
    Self.AddItem(Result);
  end;
  Result.UpdateFrom(Item);
end;

function TDnmpContactList.Extract(Item: TDnmpContact): Boolean;
begin
  Result:=Assigned(FObjectList.Extract(Item));
end;

procedure TDnmpContactList.Clear();
begin
  FObjectList.Clear();
end;

function TDnmpContactList.HaveItem(Item: TDnmpContact): Boolean;
begin
  Result:=not (FObjectList.IndexOf(Item) = -1);
end;

function TDnmpContactList.ToStorage(InfoType: TDnmpContactInfoType
  ): TDataStorage;
var
  Storage: TDataStorage;
  i: Integer;
begin
  Storage:=TDataStorage.Create(stDictionary);
  for i:=0 to Self.Count-1 do
  begin
    Storage.Add(IntToStr(i), Self.Items[i].ToStorage(InfoType));
  end;

  Result:=TDataStorage.Create(stDictionary);
  Result.Add('type', 'DnmpContactList');
  Result.Add('items', Storage);
end;

function TDnmpContactList.FromStorage(Storage: TDataStorage): Boolean;
var
  SubStorage: TDataStorage;
  i: Integer;
  Item: TDnmpContact;
begin
  Result:=False;
  if not Assigned(Storage) then Exit;
  if Storage.StorageType <> stDictionary then Exit;
  if Storage.GetString('type')<>'DnmpContactList' then Exit;
  SubStorage:=Storage.GetObject('items');
  if SubStorage.StorageType <> stDictionary then Exit;
  for i:=0 to SubStorage.Count-1 do
  begin
    Item:=TDnmpContact.Create();
    if not Item.FromStorage(SubStorage.GetObject(i)) then
    begin
      Item.Free();
      Continue;
    end;
    if Length(Item.GUID)>=4 then
    begin
      //self.Add(Item);
      Self.UpdateItem(Item);
    end;
  end;
  Result:=True;
end;

{ TDnmpContact }

function TDnmpContact.FGetInfo(AName: string): string;
var
  i: integer;
  Item: TDnmpContactInfo;
begin
  Result:='';
  for i:=0 to FInfoList.Count-1 do
  begin
    Item:=(FInfoList.Items[i] as TDnmpContactInfo);
    if Item.Name=AName then
    begin
      Result:=Item.Value;
      Exit;
    end;
  end;
end;

procedure TDnmpContact.FSetInfo(AName: string; AValue: string);
var
  i: integer;
  Item: TDnmpContactInfo;
begin
  if AName='' then Exit;
  Item:=nil;
  for i:=0 to FInfoList.Count-1 do
  begin
    Item:=(FInfoList.Items[i] as TDnmpContactInfo);
    if Item.Name=AName then Break;
    Item:=nil;
  end;
  if not Assigned(Item) then
  begin
    Item:=(FInfoList.Add() as TDnmpContactInfo);
    Item.Name:=AName;
  end;
  Item.Value:=AValue;
end;

constructor TDnmpContact.Create();
begin
  inherited Create();
  Self.FInfoList:=TCollection.Create(TDnmpContactInfo);
  IncomingChat:=False;
  IncomingFile:=False;
end;

destructor TDnmpContact.Destroy();
begin
  FreeAndNil(Self.FInfoList);
  inherited Destroy();
end;

function TDnmpContact.InfoCount(): integer;
begin
  Result:=FInfoList.Count;
end;

function TDnmpContact.GetInfoName(Index: integer): string;
begin
  Result:='';
  if (Index<0) or (Index>=FInfoList.Count) then Exit;
  Result:=(FInfoList.Items[Index] as TDnmpContactInfo).Name;
end;

function TDnmpContact.GetInfo(Index: integer): string;
begin
  if (Index<0) or (Index>=FInfoList.Count) then Exit;
  Result:=(FInfoList.Items[Index] as TDnmpContactInfo).Value;
end;

function TDnmpContact.AddrStr(): string;
begin
  Result:=AddrToStr(Self.Addr);
end;

function TDnmpContact.SameAddr(AAddr: TAddr): Boolean;
begin
  Result:=((Self.Addr.Node=AAddr.Node) and (Self.Addr.Point=AAddr.Point));
end;

function TDnmpContact.ToStorage(InfoType: TDnmpContactInfoType): TDataStorage;
var
  i: integer;
  InfoItem: TDnmpContactInfo;
  SubStorage: TDataStorage;
begin
  Result:=TDataStorage.Create(stDictionary);
  // Brief info
  Result.Add('addr', AddrToStr(Self.Addr));
  Result.Add('guid', Self.GUID);
  Result.Add('name', Self.Name);
  Result.Add('state', Self.StateStr());
  if InfoType=ctBrief then Exit;

  // Public info
  Result.Add('senior_guid', Self.SeniorGUID);
  Result.Add('status', Self.StatusMessage);
  Result.Add('picture', Self.Picture);
  Result.Add('rating', Self.Rating);
  if InfoType=ctPublic then Exit;

  // Private info
  Result.Add('owner', Self.Owner);
  Result.Add('location', Self.Location);
  Result.Add('ip_addr', Self.IpAddr);
  Result.Add('phone_no', Self.PhoneNo);
  Result.Add('other_info', Self.OtherInfo);
  Result.Add('key', Self.Key);

  SubStorage:=TDataStorage.Create(stDictionary);
  for i:=0 to FInfoList.Count-1 do
  begin
    InfoItem:=(FInfoList.Items[i] as TDnmpContactInfo);
    SubStorage.Add(InfoItem.Name, InfoItem.Value);
  end;
  Result.Add('info', SubStorage);
  if InfoType=ctPrivate then Exit;

  // Temporary info
  //Result.Add('online', BoolToStr(Self.Online, '1', '0'));
  //Result.Add('link_type', LinkTypeToStr(Self.LinkType));
end;

function TDnmpContact.FromStorage(Storage: TDataStorage): Boolean;
var
  i: integer;
  //InfoItem: TDnmpContactInfo;
  SubStorage: TDataStorage;
  sName: string;
begin
  Result:=False;
  if not Assigned(Storage) then Exit;
  if Storage.StorageType <> stDictionary then Exit;

  // Brief info
  Self.Addr:=StrToAddr(Storage.GetString('addr'));
  Self.GUID:=Storage.GetString('guid');
  Self.Name:=Storage.getString('name');
  Self.StateFromStr(Storage.GetString('state'));

  // Public info
  if Storage.HaveName('senior_guid') then
  begin
    Self.SeniorGUID:=Storage.GetString('senior_guid');
    Self.StatusMessage:=Storage.GetString('status');
    Self.Picture:=Storage.GetString('picture');
    Self.Rating:=Storage.GetInteger('rating');
  end;

  // Private info
  if Storage.HaveName('owner') then
  begin
    Self.Owner:=Storage.GetString('owner');
    Self.Location:=Storage.GetString('location');
    Self.IpAddr:=Storage.GetString('ip_addr');
    Self.PhoneNo:=Storage.GetString('phone_no');
    Self.OtherInfo:=Storage.GetString('other_info');
    Self.Key:=Storage.GetString('key');
    // info
    SubStorage:=Storage.GetObject('info');
    if Assigned(SubStorage) then
    begin
      for i:=0 to SubStorage.Count()-1 do
      begin
        sName:=SubStorage.GetObjectName(i);
        Self.Info[sName]:=SubStorage.GetString(sName);
      end;
    end;
  end;

  // Temporary info
  if Addr.Point=0 then IsNode:=True else IsNode:=False;
  {
  if Storage.HaveName('link_type') then
  begin
    //Self.LinkType:=StrToLinkType(Storage.GetString('link_type'));
    //Self.Online:=(Storage.GetString('online')='1');
  end;
  }

  Result:=True;
end;

function TDnmpContact.StateStr(): string;
begin
  Result:='Unknown';
  case State of
    asUnknown: Result:='Unknown';
    asOnline: Result:='Online';
    asOffline: Result:='Offline';
    asBusy: Result:='Busy';
  end;
end;

function TDnmpContact.StateFromStr(s: string): Boolean;
begin
  Result:=True;
  if s='Unknown' then State:=asUnknown
  else if s='Online' then State:=asOnline
  else if s='Offline' then State:=asOffline
  else if s='Busy' then State:=asBusy
  else Result:=False;
end;

procedure TDnmpContact.Assign(Item: TDnmpContact);
var
  i: integer;
  InfoItem1, InfoItem2: TDnmpContactInfo;
begin
  if not Assigned(Item) then Exit;
  // Brief
  Self.Name:=Item.Name;
  Self.Addr:=Item.Addr;
  Self.GUID:=Item.GUID;
  Self.State:=Item.State;
  // Public
  Self.SeniorGUID:=Item.SeniorGUID;
  Self.StatusMessage:=Item.StatusMessage;
  Self.Picture:=Item.Picture;
  Self.Rating:=Item.Rating;
  // Private
  Self.Owner:=Item.Owner;
  Self.Location:=Item.Location;
  Self.IpAddr:=Item.IpAddr;
  Self.PhoneNo:=Item.PhoneNo;
  Self.OtherInfo:=Item.OtherInfo;
  Self.Key:=Item.Key;
  // Info
  for i:=0 to Item.FInfoList.Count-1 do
  begin
    InfoItem1:=(Item.FInfoList.Items[i] as TDnmpContactInfo);
    Self.Info[InfoItem1.Name]:=InfoItem1.Value;
  end;
  // Temp
  //Self.Online:=Item.Online;
  //Self.LinkType:=Item.LinkType;
end;

procedure TDnmpContact.UpdateFrom(Item: TDnmpContact);
var
  i: integer;
  InfoItem1, InfoItem2: TDnmpContactInfo;
begin
  if not Assigned(Item) then Exit;
  // Brief
  if Item.Name<>'' then Self.Name:=Item.Name;
  if not IsEmptyAddr(Item.Addr) then Self.Addr:=Item.Addr;
  if Item.GUID<>'' then Self.GUID:=Item.GUID;
  Self.State:=Item.State;
  // Public
  if Item.SeniorGUID<>'' then Self.SeniorGUID:=Item.SeniorGUID;
  if Item.StatusMessage<>'' then Self.StatusMessage:=Item.StatusMessage;
  if Item.Picture<>'' then Self.Picture:=Item.Picture;
  if Item.Rating<>0 then Self.Rating:=Item.Rating;
  // Private
  if Item.Owner<>'' then Self.Owner:=Item.Owner;
  if Item.Location<>'' then Self.Location:=Item.Location;
  if Item.IpAddr<>'' then Self.IpAddr:=Item.IpAddr;
  if Item.PhoneNo<>'' then Self.PhoneNo:=Item.PhoneNo;
  if Item.OtherInfo<>'' then Self.OtherInfo:=Item.OtherInfo;
  if Item.Key<>'' then Self.Key:=Item.Key;
  // Info
  for i:=0 to Item.FInfoList.Count-1 do
  begin
    InfoItem1:=(Item.FInfoList.Items[i] as TDnmpContactInfo);
    if InfoItem1.Value<>'' then Self.Info[InfoItem1.Name]:=InfoItem1.Value;
  end;
  // Temp
  //Self.Online:=Item.Online;
  //Self.LinkType:=Item.LinkType;
end;


{ === TDnmpMsg === }

constructor TDnmpMsg.Create();
begin
  inherited Create();
  self.Info:=TStringList.Create();
  self.Data:=TMemoryStream.Create();
  SetLength(Self.SeenBy, 0);
end;

constructor TDnmpMsg.Create(SAddr, TAddr: TAddr; AMsgType, Params,
  DataStr: string);
var
  ss: TStringStream;
begin
  inherited Create();
  Self.SourceAddr:=SAddr;
  Self.TargetAddr:=TAddr;
  Self.MsgType:=AMsgType;
  Inc(iMsgSerialNum);
  Self.SerialNum:=iMsgSerialNum;
  Self.TimeStamp:=Now();
  Self.Info:=TStringList.Create();
  Self.Info.Text:=Params;
  //self.Info.Values['timestamp']:=Misc.GetTimestampStr();
  Self.Data:=TMemoryStream.Create();
  Self.Data.Clear();
  if Length(DataStr)>0 then
  begin
    ss:=TStringStream.Create(DataStr);
    ss.Seek(0, soFromBeginning);
    Self.Data.CopyFrom(ss, ss.Size);
    ss.Free();
  end;
  SetLength(Self.SeenBy, 0);
  //self.ReadFromStr(Str);
end;

destructor TDnmpMsg.Destroy();
begin
  self.Data.Free();
  self.Info.Free();
  inherited Destroy();
end;

function TDnmpMsg.FromString(Str: AnsiString): Boolean;
var
  ss: TStringStream;
begin
  ss:=TStringStream.Create(Str);
  ss.Seek(0, soFromBeginning);
  Result:=Self.FromStream(ss);
  ss.Free();
end;

{function TDnmpMsg.FromString(Str: string): Boolean;
var
  n, i: integer;
  s, s2: string;
begin
  s:=Str;
  i:=1;
  while i<4 do
  begin
    n:=Pos('|', s);
    if n=0 then Break;
    if n>1 then
    begin
      s2:='';
      case i of
        1: s2:='MsgType';
        2: s2:='Timestamp';
        3: s2:='SrcAddr';
        4: s2:='DstAddr';
      end;
      self.Info.Values[s2]:=Copy(s, 1, n-1);
    end;
    Inc(i);
    s:=Copy(s, n+1, maxint);
  end;
  self.Info.Values['MsgBody']:=s;
end;}

function TDnmpMsg.ToString(): AnsiString;
var
  ss: TStringStream;
begin
  ss:=TStringStream.Create('');
  ss.Seek(0, soFromBeginning);
  Self.ToStream(ss);
  Result:=ss.DataString;
  ss.Free();
end;

function TDnmpMsg.FromStream(AStream: TStream): Boolean;
var
  ms: TMemoryStream;
  iMsgSize, iParamsSize, iDataSize, iSeenbyOffset, iSeenbySize, iSeenByCount: Cardinal;
  TmpMsgType: array [0..3] of AnsiChar;
begin
  Result:=False;
  if not Assigned(AStream) then Exit;
  iSeenbyOffset:=0;
  iParamsSize:=0;
  iDataSize:=0;
  AStream.Seek(0, soFromBeginning);
  //AStream.Read(iMsgSize, SizeOf(iMsgSize));
  //if iMsgSize<>(AStream.Size-SizeOf(iMsgSize)) then Exit;
  AStream.Read(TmpMsgType, SizeOf(TmpMsgType));
  Self.MsgType:=TmpMsgType;
  //AStream.Read(Self.TimeStamp, SizeOf(Self.TimeStamp));
  AStream.Read(Self.SerialNum, SizeOf(Self.SerialNum));
  AStream.Read(Self.SourceAddr, SizeOf(Self.SourceAddr));
  AStream.Read(Self.TargetAddr, SizeOf(Self.TargetAddr));
  AStream.Read(iSeenbyOffset, SizeOf(iSeenbyOffset));
  AStream.Read(iParamsSize, SizeOf(iParamsSize));

  Self.Info.Clear();
  ms:=TMemoryStream.Create();
  ms.CopyFrom(AStream, iParamsSize);
  ms.Seek(0, soFromBeginning);
  Self.Info.LoadFromStream(ms);
  FreeAndNil(ms);

  Self.Data.Clear();
  AStream.Read(iDataSize, SizeOf(iDataSize));
  if iDataSize<>0 then Self.Data.CopyFrom(AStream, iDataSize);

  iSeenbySize:=AStream.Size-AStream.Position;
  if (iSeenbySize>0) and ((iSeenbySize mod 4)=0) then
  begin
    //ms.Write(Self.SeenBy, Length(Self.SeenBy)*SizeOf(TNodeID));
    //AStream.Read(Self.SeenBy, iSeenbySize);
    iSeenByCount:=(iSeenbySize mod 4);
    SetLength(Self.SeenBy, iSeenByCount);
    while iSeenByCount > 0 do
    begin
      AStream.Read(Self.SeenBy[iSeenByCount], SizeOf(TNodeID));
    end;
  end;
  Result:=True;
end;

function TDnmpMsg.ToStream(AStream: TStream): Boolean;
var
  ms: TMemoryStream;
  iParamsSize, iDataSize, iSeenbyOffset: Cardinal;
  FourCC: array [0..3] of AnsiChar;
  i, n: Integer;
begin
  Result:=False;
  if not Assigned(AStream) then Exit;
  iParamsSize:=Length(Self.Info.Text);
  iDataSize:=Self.Data.Size;
  iSeenbyOffset:=Length(Self.SeenBy)*SizeOf(TNodeID);
  SetLength(MsgType, 4);
  for i:=0 to 3 do FourCC[i]:=MsgType[i+1];

  ms:=TMemoryStream.Create();
  ms.Write(FourCC, SizeOf(FourCC));  // 4 bytes
  //ms.Write(Self.TimeStamp, SizeOf(Self.TimeStamp));
  ms.Write(Self.SerialNum, SizeOf(Self.SerialNum));   // 4 bytes
  ms.Write(Self.SourceAddr, SizeOf(Self.SourceAddr)); // 8 bytes
  ms.Write(Self.TargetAddr, SizeOf(Self.TargetAddr)); // 8 bytes
  ms.Write(iSeenbyOffset, SizeOf(iSeenbyOffset));     // 4 bytes
  ms.Write(iParamsSize, SizeOf(iParamsSize));         // 4 bytes
  Self.Info.SaveToStream(ms);
  ms.Write(iDataSize, SizeOf(iDataSize));             // 4 bytes
  Self.Data.Seek(0, soFromBeginning);
  ms.CopyFrom(Self.Data, iDataSize);
  {
  if Length(Self.SeenBy)>0 then
  begin
    //ms.Write(Self.SeenBy, Length(Self.SeenBy)*SizeOf(TNodeID));
    ms.Write(Self.SeenBy, SizeOf(Self.SeenBy));
  end;
  }
  for i:=0 to Length(Self.SeenBy)-1 do
  begin
    ms.Write(Self.SeenBy[i], SizeOf(TNodeID));
  end;

  ms.Seek(0, soFromBeginning);
  AStream.Size:=ms.Size;
  AStream.Seek(0, soFromBeginning);
  ms.SaveToStream(AStream);
  FreeAndNil(ms);
  Result:=True;
end;

function TDnmpMsg.ParseInfo(Str: string): Boolean;
var
  sl: TStringList;
  i: integer;
begin
  sl:=TStringList.Create();
  sl.Delimiter:='|';
  sl.DelimitedText:=Str;
  for i:=0 to sl.Count-1 do Self.Info.Add(sl[i]);
  sl.Free();
  Result:=True;
end;

/// Проверяет наличие адреса в синбаях
function TDnmpMsg.HaveSeenBy(Addr: TAddr): Boolean;
var
  i: Integer;
begin
  Result:=False;
  for i:=0 to Length(Self.SeenBy)-1 do
  begin
    if Self.SeenBy[i] = Addr.Node then
    begin
      Result:=True;
      Break;
    end;
  end;
end;

/// Добавляет адрес в синбаи
function TDnmpMsg.AddSeenBy(Addr: TAddr): Boolean;
begin
  Result:=False;
  if HaveSeenBy(Addr) then Exit;
  SetLength(Self.SeenBy, Length(Self.SeenBy)+1);
  Self.SeenBy[Length(Self.SeenBy)-1]:=Addr.Node;
  Result:=True;
end;


// === TDnmpMsgQueue ===
function TDnmpMsgQueue.GetMsg(Index: Integer): TDnmpMsg;
begin
  Result:=TDnmpMsg(inherited Items[index]);
end;

procedure TDnmpMsgQueue.SetMsg(Index: Integer; Value: TDnmpMsg);
begin
  inherited Items[Index]:=Value;
end;

function TDnmpMsgQueue.GetMsgByAddr(FAddr: TAddr): TDnmpMsg;
var
  i: Integer;
begin
  Result:=nil;
  for i:=0 to Count-1 do
  begin
    if SameAddr(TDnmpMsg(Items[i]).TargetAddr, FAddr) then
    begin
      Result:=TDnmpMsg(Items[i]);
      Exit;
    end;
  end;
end;

function TDnmpMsgQueue.ToStorage(): TDataStorage;
var
  Storage: TDataStorage;
  i: Integer;
begin
  Storage:=TDataStorage.Create(stDictionary);
  for i:=0 to Self.Count-1 do
  begin
    Storage.Add(IntToStr(i), Self.Items[i].ToString());
  end;

  Result:=TDataStorage.Create(stDictionary);
  Result.Add('type', 'DnmpMsgQueue');
  Result.Add('items', Storage);
end;

function TDnmpMsgQueue.FromStorage(Storage: TDataStorage): Boolean;
var
  SubStorage: TDataStorage;
  i: Integer;
  Item: TDnmpMsg;
begin
  Result:=False;
  if not Assigned(Storage) then Exit;
  if Storage.StorageType <> stDictionary then Exit;
  if Storage.GetString('type')<>'DnmpMsgQueue' then Exit;
  SubStorage:=Storage.GetObject('items');
  if SubStorage.StorageType <> stDictionary then Exit;
  for i:=0 to SubStorage.Count-1 do
  begin
    Item:=TDnmpMsg.Create();
    if not Item.FromString(SubStorage.GetString(IntToStr(i))) then
    begin
      Item.Free();
      Continue;
    end;
    self.Add(Item);
  end;
  Result:=True;
end;

procedure TDnmpMsgQueue.SaveToFile(Filename: string);
var
  i: Integer;
  msSize: Cardinal;
  fs: TFileStream;
  ms: TMemoryStream;
begin
  if Count=0 then
  begin
    if FileExists(Filename) then DeleteFile(Filename);
    Exit;
  end;
  fs:=TFileStream.Create(Filename, fmCreate);
  ms:=TMemoryStream.Create();
  for i:=0 to Count-1 do
  begin
    ms.Clear();
    Items[i].ToStream(ms);
    ms.Position:=0;
    msSize:=ms.Size;
    fs.WriteBuffer(msSize, SizeOf(msSize));
    fs.CopyFrom(ms, msSize);
  end;
  ms.Free();
  fs.Free();
end;

function TDnmpMsgQueue.LoadFromFile(Filename: string): Boolean;
var
  msSize: Cardinal;
  fs: TFileStream;
  ms: TMemoryStream;
  msg: TDnmpMsg;
begin
  Result:=false;
  msSize:=0;
  Self.Clear();
  if not FileExists(Filename) then Exit;
  try
    fs:=TFileStream.Create(Filename, fmOpenRead);
  except
    FreeAndNil(fs);
    Exit;
  end;
  fs.Position:=0;
  ms:=TMemoryStream.Create();

  repeat
    try
      fs.ReadBuffer(msSize, SizeOf(msSize));
    except
      Break;
    end;
    ms.Clear();
    ms.CopyFrom(fs, msSize);
    msg:=TDnmpMsg.Create(EmptyAddr, EmptyAddr, '','','');
    if msg.FromStream(ms) then Self.Add(msg) else msg.Free();
  until fs.Position = fs.Size;
  ms.Free();
  fs.Free();

  Result:=True;
end;


// === TLinkList ===
function TDnmpLinkList.GetLink(Index: Integer): TDnmpLink;
begin
  Result:=TDnmpLink(inherited Items[index]);
end;

procedure TDnmpLinkList.SetLink(Index: Integer; Value: TDnmpLink);
begin
  inherited Items[Index]:=Value;
end;

function TDnmpLinkList.GetLinkByAddr(FAddr: TAddr): TDnmpLink;
var
  i: Integer;
begin
  Result:=nil;
  for i:=0 to Count-1 do
  begin
    if SameAddr(TDnmpLink(Items[i]).RemoteInfo.Addr, FAddr) then
    begin
      Result:=TDnmpLink(Items[i]);
      Exit;
    end;
  end;
end;

procedure TDnmpLinkList.RemoveInactive();
var
  i: integer;
  Item: TDnmpLink;
begin
  for i:=Self.Count-1 downto 0 do
  begin
    Item:=Self.GetLink(i);
    if Item.Active then Continue;
    Self.Delete(i);
  end;
end;

// === TDnmpRoutingTable ===
constructor TDnmpRoutingTable.Create(ALinks: TDnmpLinkList);
begin
  Self.Links:=ALinks;
  SetLength(FItems, 0);
end;

destructor TDnmpRoutingTable.Destroy();
begin
  SetLength(FItems, 0);
end;

function TDnmpRoutingTable.FGetGateForDest(DestID: TNodeID; var GateID: TNodeID): Boolean;
var
  i: Integer;
begin
  Result:=False;
  for i:=0 to FCount-1 do
  begin
    if FItems[i].DestNodeID = DestID then
    begin
      GateID:=FItems[i].GateNodeID;
      Result:=True;
      Exit;
    end;
  end;
end;

procedure TDnmpRoutingTable.AddItem(GateID, DestID: TNodeID; TraceID: Cardinal);
var
  i: Integer;
begin
  for i:=0 to FCount-1 do
  begin
    if FItems[i].DestNodeID = DestID then
    begin
      if GateID = FItems[i].GateNodeID then Exit;
      if TraceID = FItems[i].TraceID then Exit;
      GateID:=FItems[i].GateNodeID;
      Exit;
    end;
  end;

  Inc(FCount);
  SetLength(FItems, FCount);
  FItems[FCount-1].DestNodeID:=DestID;
  FItems[FCount-1].GateNodeID:=GateID;
  FItems[FCount-1].TraceID:=TraceID;
end;

procedure TDnmpRoutingTable.AddRountingItems(GateID: TNodeID; TraceID: Cardinal; SeenBy: TSeenBy);
var
  i: Integer;
begin
  for i:=0 to Length(SeenBy)-1 do
  begin
    AddItem(GateID, SeenBy[i], TraceID);
  end;
end;

function TDnmpRoutingTable.LinkForDestAddr(Addr: TAddr): TDnmpLink;
var
  i: Integer;
  GateID: TNodeID;
begin
  Result:=nil;
  if not Assigned(Links) then Exit;
  GateID:=0;
  if not FGetGateForDest(Addr.Node, GateID) then Exit;

  for i:=0 to Links.Count-1 do
  begin
    if (Links[i] as TDnmpLink).RemoteInfo.Addr.Node = GateID then
    begin
      Result:=(Links[i] as TDnmpLink);
      Exit;
    end;
  end;
end;

// Удаляет все записи с указанным GateID
procedure TDnmpRoutingTable.DelGate(GateID: TNodeID);
var
  i: Integer;
begin
  for i:=FCount-1 downto 0 do
  begin
    if FItems[i].GateNodeID = GateID then
    begin
      Dec(FCount);
      if i<(FCount) then FItems[i]:=FItems[FCount];
      SetLength(FItems, FCount);
    end;
  end;
end;

// Удаляет запись с указанным DestID
procedure TDnmpRoutingTable.DelDest(DestID: TNodeID);
var
  i: Integer;
begin
  for i:=FCount-1 downto 0 do
  begin
    if FItems[i].DestNodeID = DestID then
    begin
      Dec(FCount);
      if i<(FCount) then FItems[i]:=FItems[FCount];
      SetLength(FItems, FCount);
      Exit;
    end;
  end;
end;

// Удаляет все записи
procedure TDnmpRoutingTable.Clear();
begin
  FCount:=0;
  SetLength(FItems, FCount);
end;

function TDnmpRoutingTable.ToStorage(): TDataStorage;
var
  Storage: TDataStorage;
  i: Integer;

function RoutingRecordToStorage(Item: TDnmpRoutingTableRecord): TDataStorage;
begin
  Result:=TDataStorage.Create(stDictionary);
  Result.Add('dest_node_id', IntToStr(Item.DestNodeID));
  Result.Add('gate_node_id', IntToStr(Item.GateNodeID));
  Result.Add('trace_id', IntToStr(Item.TraceID));
end;

begin
  Storage:=TDataStorage.Create(stDictionary);
  for i:=0 to Self.Count-1 do
  begin
    Storage.Add(IntToStr(i), RoutingRecordToStorage(Self.Items[i]));
  end;

  Result:=TDataStorage.Create(stDictionary);
  Result.Add('type', 'DnmpRoutingTable');
  Result.Add('items', Storage);
end;

function TDnmpRoutingTable.FromStorage(Storage: TDataStorage): Boolean;
var
  SubStorage, AStorage: TDataStorage;
  i: Integer;
  Item: TDnmpRoutingTableRecord;
begin
  Result:=False;
  if not Assigned(Storage) then Exit;
  if Storage.StorageType <> stDictionary then Exit;
  if Storage.GetString('type')<>'DnmpRoutingTable' then Exit;
  SubStorage:=Storage.GetObject('items');
  if SubStorage.StorageType <> stDictionary then Exit;
  for i:=0 to SubStorage.Count-1 do
  begin
    AStorage:=SubStorage.GetObject(i);
    if AStorage.StorageType <> stDictionary then Continue;
    Item.DestNodeID:=AStorage.GetCardinal('dest_node_id');
    Item.GateNodeID:=AStorage.GetCardinal('gate_node_id');
    Item.TraceID:=AStorage.GetCardinal('trace_id');

    self.AddItem(Item.DestNodeID, Item.GateNodeID, Item.TraceID);
  end;
  Result:=True;
end;


// === TDnmpLink ===
constructor TDnmpLink.Create(AMgr: TDnmpManager; ARemoteInfo: TDnmpContact);
begin
  inherited Create();
  Mgr:=AMgr;
  NodesUnder:=TNodeList.Create(Mgr.ContactList);
  MyInfo:=Mgr.MyInfo;
  LinkType:=ltTemporary;
  RemoteInfo:=ARemoteInfo;
  if not Assigned(RemoteInfo) then RemoteInfo:=TDnmpContact.Create();
end;

destructor TDnmpLink.Destroy();
begin
  // remove events
  OnConnect:=nil;
  OnDisconnect:=nil;
  OnIncomingMsg:=nil;

  FreeAndNil(NodesUnder);
  inherited Destroy();
end;

function TDnmpLink.SendMsg(Msg: TDnmpMsg): Boolean;
begin
  if Assigned(Mgr) then Mgr.DebugMsg(Msg, Self, '@>');
  //Msg.AddSeenBy(MyInfo.Addr);
  Result:=Active;
end;

function TDnmpLink.Approve(): Boolean;
begin
  Result:=false;
  if not Assigned(Mgr) then Exit;
  Result:=Mgr.Approve(RemoteInfo);
end;

function TDnmpLink.Connect(): Boolean;
begin
  Result:=Assigned(MsgHandler);
end;

function TDnmpLink.Disconnect(): Boolean;
begin
  FActive:=False;
  Result:=True;
end;

function TDnmpLink.Listen(): Boolean;
begin
  Self.LinkType:=ltListener;
  Result:=Assigned(MsgHandler);
end;

function TDnmpLink.Check(): Boolean;
begin
  Result:=Active;
end;

// === TDnmpMsgHandler ===
constructor TDnmpMsgHandler.Create(AMgr: TDnmpManager; ALink: TDnmpLink);
begin
  inherited Create();
  Self.FMgr:=AMgr;
  Self.FLink:=ALink;
  if Assigned(Mgr) and (not Assigned(Link)) then
  begin
    AMgr.MsgHandlers.Add(Self);
  end;
end;

destructor TDnmpMsgHandler.Destroy();
begin
  if Assigned(Mgr) and (not Assigned(Link)) then Mgr.MsgHandlers.Extract(Self);
  inherited Destroy();
end;

function TDnmpMsgHandler.Start(): Boolean;
begin
  Result:=False;
end;

function TDnmpMsgHandler.Stop(): Boolean;
begin
  Result:=True;
end;

function TDnmpMsgHandler.Cmd(Text: string; Addr: TAddr): string;
begin
  Result:='';
end;

// ===================
// === TDnmpManager ===
// ===================
constructor TDnmpManager.Create(ConfName: string);
begin
  inherited Create();
  sDataPath:=IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(sDnmpDataDir)+ConfName);
  CheckPath(sDataPath);

  DebugText('Config file='+sDataPath+csConfigFileName);
  Conf:=TDnmpConf.Create(sDataPath+csConfigFileName);

  ContactList:=TDnmpContactList.Create(nil);
  ContactList.Filename:=csContactListFileName;

  PassportList:=TDnmpPassportList.Create(ContactList);
  PassportList.Filename:=csPassportListFileName;

  TmpContactList:=TDnmpContactList.Create(nil);

  MyInfo:=TDnmpContact.Create();
  ContactList.AddItem(MyInfo);

  MyPassport:=TDnmpPassport.Create(MyInfo, ContactList);

  NodeList:=TNodeList.Create(ContactList);
  NodeList.Filename:=csNodelistFileName;

  PointList:=TPointList.Create(ContactList);
  PointList.Filename:=csPointlistFileName;

  UnapprovedList:=TDnmpContactList.Create(nil);
  UnapprovedList.Filename:=csUnapprovedFileName;

  LinkList:=TDnmpLinkList.Create();

  RoutingTable:=TDnmpRoutingTable.Create(LinkList);

  CmdQueue:=TStringList.Create;

  MsgQueue:=TDnmpMsgQueue.Create(True);

  MsgHandlers:=TObjectList.Create(True);

  //self.Parser:=

  // default handlers, they added to MsgHandlers on Create()
  TDnmpInfoService.Create(Self, nil); // INFO
end;

destructor TDnmpManager.Destroy();
var
  i: integer;
begin
  Stop();
  SaveToFile();

  // remove events
  Self.OnLog:=nil;
  Self.OnCmd:=nil;
  Self.OnEvent:=nil;
  Self.OnIncomingMsg:=nil;

  // ServiceDirectory created not in constructor
  // delete handlers
  if Assigned(MsgHandlers) then
  begin
    // handlers remove themselves from list on Destroy()
    for i:=MsgHandlers.Count-1 downto 0 do MsgHandlers.Items[i].Free();
    FreeAndNil(MsgHandlers);
  end;

  FreeAndNil(MsgQueue);

  FreeAndNil(CmdQueue);

  FreeAndNil(RoutingTable);
  FreeAndNil(LinkList);

  FreeAndNil(UnapprovedList);
  FreeAndNil(PointList);
  FreeAndNil(NodeList);

  FreeAndNil(MyPassport);
  FreeAndNil(MyInfo);
  FreeAndNil(TmpContactList);
  FreeAndNil(PassportList);
  FreeAndNil(ContactList);
  FreeAndNil(Conf);
  inherited Destroy();
end;

procedure TDnmpManager.Init();
begin
  // clear commands
  CmdQueue.Clear();
  MsgQueue.Clear();
  // clear links
  LinkList.Clear();
  // clear contacts
  UnapprovedList.Clear();
  PointList.Clear();
  Nodelist.Clear();
  ContactList.Clear();

  //MyInfo;
  //MyPassport;
  ContactList.AddItem(MyInfo);
end;

procedure TDnmpManager.StartServer();
begin
  if Self.Active then Stop();
  self.FServerMode:=True;
  Start();
end;

procedure TDnmpManager.StartClient();
begin
  if Self.Active then Stop();
  self.FServerMode:=False;
  Start();
end;

procedure TDnmpManager.Start();
var
  tmpLinkInfo: TDnmpContact;
  tmpLink: TDnmpLink;
  sTcpPort: string;
  i: integer;
begin

  if ServerMode then
  begin
    //sTcpPort:=Conf.ReadString('Options', 'ListenTcpPort', '4044');
    // get port from my info
    sTcpPort:='';
    if Pos(':', MyInfo.IpAddr)>0 then sTcpPort:=Trim(Copy(MyInfo.IpAddr, Pos(':', MyInfo.IpAddr)+1, MaxInt));
    if sTcpPort='' then sTcpPort:='4044';

    // Create server listener link
    // {TODO: remove TIpLink, get it from outside}
    tmpLink:=TIpLink.Create(self, nil);
    (tmpLink as TIpLink).LinkHost:='';
    (tmpLink as TIpLink).LinkPort:=sTcpPort;
    tmpLink.LinkType:=ltListener;
    tmpLink.MsgHandler:=TDnmpAuthService.Create(Self, tmpLink);
    tmpLink.OnIncomingMsg:=@IncomingMsgHandler;
    if tmpLink.Listen() then
    begin
      ListenerLink:=tmpLink;
      LinkList.Add(tmpLink);
      DebugText('Server started. '+TIpLink(tmpLink).LinkHost+':'+TIpLink(tmpLink).LinkPort);
      MyInfo.State:=TDnmpContactState.asOnline;
      Event('MGR','REFRESH');
    end
    else FreeAndNil(tmpLink);
  end

  else // not ServerMode
  begin
    // get uplink addr from nodelist
    tmpLinkInfo:=NodeList.GetByAddr(NodeAddr(MyInfo.Addr));
    if not Assigned(tmpLinkInfo) then
    begin
      // get first node from list
      for i:=0 to NodeList.Count-1 do
      begin
        tmpLinkInfo:=NodeList.Items[i];
        if tmpLinkInfo<>MyInfo then Break;
        tmpLinkInfo:=nil;
      end;
      if not Assigned(tmpLinkInfo) then
      begin
        DebugText('Uplink node not found. Add it to nodelist.');
        Exit;
      end;
    end;

    // Create connection to uplink server
    StartNodeConnection(tmpLinkInfo);
  end;
end;

procedure TDnmpManager.Stop();
var
  i: integer;
begin
  if Assigned(ListenerLink) then
  begin
    ListenerLink.OnIncomingMsg:=nil;
    //FreeAndNil(ListenerLink);
    DebugText('Server stopped.');
  end;
  ListenerLink:=nil;

  if Assigned(Uplink) then
  begin
    UpLink.OnIncomingMsg:=nil;
    //if Uplink.Disconnect() then LinkList.Remove(Uplink);
    //FreeAndNil(Uplink);
    DebugText('Uplink stopped.');
  end;
  Uplink:=nil;

  // disconnect all links
  for i:=LinkList.Count-1 downto 0 do
  begin
    DelLink(LinkList.Items[i]);
  end;
end;

procedure TDnmpManager.StartNodeConnection(NodeInfo: TDnmpContact);
var
  tmpLink: TIpLink;
  sIpHost, sIpPort: string;
begin
  if not Assigned(NodeInfo) then Exit;

  // Create connection to server
  // {TODO: remove TIpLink, get it from outside}
  tmpLink:=TIpLink.Create(Self, NodeInfo);
  tmpLink.OnIncomingMsg:=@IncomingMsgHandler;
  tmpLink.LinkType:=ltOutcoming;
  tmpLink.MsgHandler:=TDnmpAuthService.Create(Self, tmpLink);

  if tmpLink.Connect() then
  begin
    if not Assigned(UpLink) then UpLink:=tmpLink;
    LinkList.Add(tmpLink);
    DebugText('Node link started. '+tmpLink.LinkHost+':'+tmpLink.LinkPort);
    MyInfo.State:=TDnmpContactState.asOnline;
    Event('MGR','REFRESH');
  end
  else FreeAndNil(tmpLink);

end;

procedure TDnmpManager.StopNodeConnection(NodeInfo: TDnmpContact);
var
  i: Integer;
  tmpLink: TDnmpLink;
begin
  if Assigned(Uplink) and SameAddr(Uplink.RemoteInfo.Addr, NodeInfo.Addr) then
  begin
    Uplink:=nil;
  end;
  for i:=0 to LinkList.Count-1 do
  begin
    tmpLink:=LinkList[i];
    if SameAddr(tmpLink.RemoteInfo.Addr, NodeInfo.Addr) then
    begin
      DebugText('Removing node link: '+AddrToStr(NodeInfo.Addr)+' '+NodeInfo.Name);
      tmpLink.OnIncomingMsg:=nil;
      DelLink(tmpLink);
      Event('MGR','REFRESH');
      Exit;
    end;
  end;
end;

function TDnmpManager.AddLink(Link: TDnmpLink): integer;
begin
  Result:=self.LinkList.Add(Link);
  Link.MsgHandler:=TDnmpAuthService.Create(Self, Link);
  if Assigned(Link.MsgHandler) then Link.MsgHandler.Start();
end;

function TDnmpManager.DelLink(Link: TDnmpLink): Boolean;
begin
  Result:=True;
  Link.OnIncomingMsg:=nil;
  if Link.Active then Link.Disconnect();
  Self.LinkList.Extract(Link);
  if Self.LinkList.Count=0 then OnAllDisconnected();
end;

procedure TDnmpManager.DebugText(s: string);
begin
  if Assigned(FOnLog) then OnLog(Self, s);
end;

procedure TDnmpManager.DebugMsg(Msg: TDnmpMsg; Link: TDnmpLink; Comment: string);
var
  s, sLinkInfo: string;
  i: integer;
begin
  // Log message
  if Assigned(FOnLog) and Assigned(Msg) then
  begin
    sLinkInfo:='';
    if Assigned(Link) then
    begin
      sLinkInfo:=AddrToStr(Link.RemoteInfo.Addr)+' '+Link.RemoteInfo.Name;
    end;
    s:='---------------------------------------------'+LineEnding
    +Comment+' '+sLinkInfo+LineEnding
    +'['+Msg.MsgType+']  '+AddrToStr(Msg.SourceAddr)+' -> '+AddrToStr(Msg.TargetAddr)+'  ('+TimestampToStr(Msg.TimeStamp)+')'+LineEnding;
    for i:=0 to Msg.Info.Count-1 do
    begin
      s:=s+Msg.Info[i]+LineEnding;
    end;
    if Msg.Data.Size > 0 then s:=s+'Data size = '+IntToStr(Msg.Data.Size)+LineEnding;
    OnLog(Self, s);
  end;
end;

procedure TDnmpManager.OnAllDisconnected();
var
  i: integer;
begin
  // если не осталось связей, то помечаем статусы контактов как неизвестные
  if Self.LinkList.Count=0 then
  begin
    MyInfo.State:=TDnmpContactState.asOffline;
    for i:=0 to Self.ContactList.Count-1 do
    begin
      Self.ContactList.Items[i].State:=asUnknown;
    end;
  end;
end;

procedure TDnmpManager.ContactConnectedIn(AContact: TDnmpContact);
var
  i: integer;
begin
  AContact.State:=asOnline;

  // Запрашиваем информацию о контакте
  RequestInfoByAddr(AContact.Addr);

  // Отправляем отложенные сообщения
  if Assigned(AContact.Passport) then
  begin
    while AContact.Passport.MsgInbox.Count>0 do
    begin
      SendMsg(AContact.Passport.MsgInbox.Items[0]);
      AContact.Passport.MsgInbox.Delete(0);
    end;
  end;

end;

procedure TDnmpManager.ContactConnectedOut(AContact: TDnmpContact);
begin
  if IsEmptyAddr(MyInfo.Addr) then
  begin
    // такого быть не должно
    DebugText('Error - connected to uplink and have empty addr!');
  end;

  { Если мы узел, то отправим информацию об узлах-даунлинках }
  if MyInfo.Addr.Point=0 then
  begin
    //SendRoutingTable();
  end;
end;

procedure TDnmpManager.IncomingMsgHandler(Sender: TObject; Msg: TDnmpMsg);
var
  i: Integer;
  Link: TDnmpLink;
begin
  if (Sender is TDnmpLink) then
    Link:=(Sender as TDnmpLink)
  else
    Exit;
  // Log message
  //DebugMsg(Msg, Link, '<<');

  // Pre-parse incomong msg
  if not Link.MsgHandler.ParseMsg(Msg) then
  begin
    // Message type unknown for parser, maybe it's service
    if SameAddr(Msg.TargetAddr, MyInfo.Addr) then
    begin
      if Assigned(MsgHandlers) then
      begin
        for i:=0 to MsgHandlers.Count-1 do
        begin
          if (MsgHandlers[i] as TDnmpMsgHandler).ParseMsg(Msg) then Break;
        end;
      end;
    end;
  end;

  if Assigned(OnIncomingMsg) then OnIncomingMsg(Link, Msg);
end;

procedure TDnmpManager.Event(Sender, Text: string);
begin
  if Pos('UPDATE LINKS', Text)<>0 then
  begin
    LinkList.RemoveInactive();
  end;
  if Assigned(OnEvent) then OnEvent(Sender, Text);
end;

function TDnmpManager.Cmd(CmdText: string): string;
begin
  Result:=CmdHandler(CmdText);
  if Assigned(OnCmd) then OnCmd(Self, CmdText);
end;

procedure TDnmpManager.AddCmd(CmdText: string);
begin
  if Assigned(CmdQueue) then CmdQueue.Add(CmdText);
end;

procedure TDnmpManager.Tick(); // Выполняет команды из очереди команд
begin
  if Assigned(CmdQueue) then
  begin
    while CmdQueue.Count>0 do
    begin
      Cmd(CmdQueue[0]);
      CmdQueue.Delete(0);
    end;
  end;
end;

procedure TDnmpManager.LoadList(List: TObject);
var
  Storage: TDataStorage;
  AContactList: TDnmpContactList;
  APassportList: TDnmpPassportList;
begin
  if not Assigned(Serializer) then Exit;
  Storage:=TDataStorage.Create(stUnknown);
  if (List is TDnmpContactList) then
  begin
    AContactList:=(List as TDnmpContactList);
    DebugText('Load contacts from '+AContactList.Filename);
    if Serializer.StorageFromFile(Storage, sDataPath+AContactList.Filename) then AContactList.FromStorage(Storage);
    DebugText(IntToStr(AContactList.Count)+' items loaded');
  end

  else if (List is TDnmpPassportList) then
  begin
    APassportList:=(List as TDnmpPassportList);
    DebugText('Load passports from '+APassportList.Filename);
    if Serializer.StorageFromFile(Storage, sDataPath+APassportList.Filename) then APassportList.FromStorage(Storage);
    DebugText(IntToStr(APassportList.Count)+' items loaded');
  end;
  Storage.Free();
end;

procedure TDnmpManager.WriteList(List: TObject; AInfoType: TDnmpContactInfoType
  );
var
  AContactList: TDnmpContactList;
  APassportList: TDnmpPassportList;
begin
  if not Assigned(Serializer) then Exit;
  if (List is TDnmpContactList) then
  begin
    AContactList:=(List as TDnmpContactList);
    DebugText('Save '+IntToStr(AContactList.Count)+' items to '+AContactList.Filename);
    Serializer.StorageToFile(AContactList.ToStorage(AInfoType), sDataPath+AContactList.Filename);
  end

  else if (List is TDnmpPassportList) then
  begin
    APassportList:=(List as TDnmpPassportList);
    DebugText('Save '+IntToStr(APassportList.Count)+' items to '+APassportList.Filename);
    Serializer.StorageToFile(APassportList.ToStorage(AInfoType), sDataPath+APassportList.Filename);
  end;
end;

procedure TDnmpManager.LoadFromFile();
var
  Sect, MainSect : string;
  i, n: Integer;
  Storage: TDataStorage;
begin
  //FServerMode:=Conf.ReadBool('Main','IsNode', False);
  if Assigned(Serializer) then
  begin
    // MyInfo
    Storage:=TDataStorage.Create(stUnknown);
    DebugText('Load MyInfo from '+csMyInfoFileName);
    if Serializer.StorageFromFile(Storage, sDataPath+csMyInfoFileName) then MyInfo.FromStorage(Storage);
    Storage.Free();

    FServerMode:=MyInfo.IsNode;

    // MyPassport
    Storage:=TDataStorage.Create(stUnknown);
    DebugText('Load MyPassport from '+csMyPassportFileName);
    if Serializer.StorageFromFile(Storage, sDataPath+csMyPassportFileName) then MyPassport.FromStorage(Storage);
    Storage.Free();

    // Contact list
    LoadList(ContactList);

    // Passport list
    LoadList(PassportList);

    // Nodelist
    LoadList(Nodelist);

    // Pointlist
    LoadList(PointList);

    // UnapprovedList
    LoadList(UnapprovedList);
  end;

  DebugText('Load MsgQueue from '+csMsgQueueFileName);
  MsgQueue.LoadFromFile(sDataPath+csMsgQueueFileName);
  DebugText(IntToStr(MsgQueue.Count)+' items loaded');

  Event('MGR', 'REFRESH');
end;

procedure TDnmpManager.SaveToFile();
var
  Sect: string;
  i: Integer;
begin
  DebugText('Save '+IntToStr(MsgQueue.Count)+' items to '+csMsgQueueFileName);
  MsgQueue.SaveToFile(sDataPath+csMsgQueueFileName);

  if Assigned(Serializer) then
  begin
    // MyInfo
    DebugText('Save MyInfo to '+csMyInfoFileName);
    Serializer.StorageToFile(MyInfo.ToStorage(ctAll), Self.sDataPath+csMyInfoFileName);

    // MyPassport
    DebugText('Save MyPassport to '+csMyPassportFileName);
    Serializer.StorageToFile(MyPassport.ToStorage(), Self.sDataPath+csMyPassportFileName);

    // ContactList
    WriteList(ContactList, ctAll);

    // PassportList
    WriteList(PassportList, ctAll);

    // Nodelist
    WriteList(Nodelist, ctBrief);

    // Pointlist
    WriteList(PointList, ctBrief);

    // UnapprovedList
    WriteList(UnapprovedList, ctAll);
  end;
end;

function TDnmpManager.SendMsg(Msg: TDnmpMsg): Boolean;
var
  i: integer;
  TargetPoint: TPointID;
  DnmpLink: TDnmpLink;
  TmpContact: TDnmpContact;
begin
  Result:=true;

  if Self.ServerMode then // If we are node
  begin
    // Add seen-by to transit message
    if (not SameNode(Msg.SourceAddr, MyInfo.Addr))
    and (not SameNode(Msg.TargetAddr, MyInfo.Addr))
    then Msg.AddSeenBy(MyInfo.Addr);

    // Сообщение другому поинту этого узла
    if Msg.TargetAddr.Node = MyInfo.Addr.Node then
    begin
      TargetPoint:=Msg.TargetAddr.Point;

      // Сообщение самому узлу
      if TargetPoint = MyInfo.Addr.Point then
      begin
        Exit;
      end;

      // Поиск поинта назначения в списке поинт-линков
      for i:=0 to LinkList.Count-1 do
      begin
        if not LinkList[i].Active then Continue;
        if not LinkList[i].RemoteInfo.SameAddr(Msg.TargetAddr) then Continue;
        // Отправка сообщения поинту через установленный линк
        LinkList[i].SendMsg(Msg);
        Exit;
      end;

      // Поиск поинта назначения в поинтлисте
      for i:=0 to PointList.Count-1 do
      begin
        if PointList[i].Addr.Point = TargetPoint then
        begin
          TmpContact:=PointList[i];
          // Помещаем сообщение в очередь отправки поинту
          if Assigned(TmpContact.Passport) then TmpContact.Passport.MsgInbox.Add(Msg);
          // отправляем уведомление о задержке сообщения
          SendErrorMsg(Msg.SourceAddr, '201', 'Message delayed');
          DebugText('201 - Message delayed');
          Exit;
        end;
      end;

      // Поинта назначения нет в поинтлисте, возвращаем ошибку
      //SendErrorMsg(Msg, '101', 'Destination point not found');
      DebugText('101 - Destination point not found');
      Result:=False;
      Exit;
    end;

    // Сообщение на другой узел
    {
    // Сообщение всем узлам
    if SameAddr(Msg.TargetAddr, EmptyAddr()) then
    begin
      // Отправка сообщения на узлы-линки
      for i:=0 to LinkList.Count-1 do
      begin
        if not LinkList[i].Active then Continue;
        if LinkList[i].RemoteInfo.Addr.Point <> 0 then Continue;
        if Msg.HaveSeenBy(LinkList[i].RemoteInfo.Addr) then Continue;
        LinkList[i].SendMsg(Msg);
      end;
      // Отправка на аплинк
      if Assigned(Uplink) then
      begin
        if not Msg.HaveSeenBy(Uplink.RemoteInfo.Addr) then Uplink.SendMsg(Msg);
      end;
      Exit;
    end;
    }

    // Поиск среди узлов-линков
    for i:=0 to LinkList.Count-1 do
    begin
      //if LinkList[i].LinkType <> ltNode then Continue;
      if not LinkList[i].Active then Continue;
      if not SameNode(LinkList[i].RemoteInfo.Addr, Msg.TargetAddr) then Continue;
      if Msg.HaveSeenBy(LinkList[i].RemoteInfo.Addr) then Continue;
      // Отправка сообщения на узел
      LinkList[i].SendMsg(Msg);
      Exit;
    end;

    // Отправка по правилам роутинга
    DnmpLink:=RoutingTable.LinkForDestAddr(Msg.TargetAddr);
    if Assigned(DnmpLink) then
    begin
      if (DnmpLink.Active) and (not Msg.HaveSeenBy(DnmpLink.RemoteInfo.Addr)) then
      begin
        DnmpLink.SendMsg(Msg);
        Exit;
      end;
    end;
  end;

  // Если аплинк существует
  if Assigned(Uplink) then
  begin
    if (Uplink.Active) and (not Msg.HaveSeenBy(Uplink.RemoteInfo.Addr)) then
    begin
      // Отправка на аплинк
      Uplink.SendMsg(Msg);
      Exit;
    end;
  end;

  // Отправка сообщения об ошибке
  SendErrorMsg(Msg.SourceAddr, '102', 'Destination address not found');
  DebugText('102 - Destination address not found');
  Result:=False;
  Exit;

end;

procedure TDnmpManager.SendDataMsg(DestAddr: TAddr; MsgType, Info, Text: string);
var
  NewMsg: TDnmpMsg;
begin
  NewMsg:=TDnmpMsg.Create(Self.MyInfo.Addr, DestAddr, MsgType, Info, Text);
  self.SendMsg(NewMsg);
  FreeAndNil(NewMsg);
end;

procedure TDnmpManager.SendErrorMsg(DestAddr: TAddr; ErrCode, ErrText: string);
begin
  SendDataMsg(DestAddr, 'INFO', 'cmd=ERRR'+CRLF+'err_code='+ErrCode, ErrText);
end;

function TDnmpManager.SendBroadcastMsg(Msg: TDnmpMsg; Destinations: string
  ): Boolean;
var
  i: integer;
begin
  Result:=False;
  if (Destinations='points') or (Destinations='all') then
  begin
    for i:=0 to LinkList.Count-1 do
    begin
      if LinkList.Items[i].LinkType=ltListener then Continue;
      if LinkList.Items[i].LinkType=ltTemporary then Continue;
      if LinkList.Items[i].RemoteInfo.Addr.Point=0 then Continue;
      Msg.TargetAddr:=LinkList.Items[i].RemoteInfo.Addr;
      Result:=Self.SendMsg(Msg);
    end;
  end;
  if (Destinations='nodes') or (Destinations='all') then
  begin
    for i:=0 to LinkList.Count-1 do
    begin
      if LinkList.Items[i].LinkType=ltListener then Continue;
      if LinkList.Items[i].LinkType=ltTemporary then Continue;
      if LinkList.Items[i].RemoteInfo.Addr.Point<>0 then Continue;
      Msg.TargetAddr:=LinkList.Items[i].RemoteInfo.Addr;
      Result:=Self.SendMsg(Msg);
    end;
  end;
end;

procedure TDnmpManager.FSetUplink(Value: TDnmpLink);
begin
  if Assigned(FUplink) then FUplink.OnIncomingMsg:=nil;
  FUplink:=Value;
  if Assigned(FUplink) then FUplink.OnIncomingMsg:=@IncomingMsgHandler;
end;

procedure TDnmpManager.FSetListenerLink(Value: TDnmpLink);
begin
  if Assigned(FListenerLink) then FListenerLink.OnIncomingMsg:=nil;
  FListenerLink:=Value;
  if Assigned(FListenerLink) then FListenerLink.OnIncomingMsg:=@IncomingMsgHandler;
end;

function TDnmpManager.FActive(): Boolean;
begin
  if Self.ServerMode then Result:=Assigned(ListenerLink);
  if not Self.ServerMode then Result:=Assigned(Uplink);
end;

function TDnmpManager.CmdHandler(CmdText: string): string;
var
  sCmd, sParams, s, s2: string;
  //saParams: TStringArray;
  i: Integer;
  TraceID: Cardinal;
  Msg: TDnmpMsg;
  TmpInfo: TDnmpContact;
begin
  Result:='';
  sCmd:='';
  sParams:=CmdText;
  sCmd:=ExtractFirstWord(sParams);
  if sCmd='AUTH' then
  begin
    if sParams='OK' then
    begin
      // Мы успешно авторизировались
      DebugText('AUTH OK');
    end

    else if sParams='FAIL' then
    begin
      // Мы не авторизировались
      DebugText('AUTH FAIL');
    end;
    Event('MGR','REFRESH');
  end

  else if sCmd='IN_AUTH' then
  begin
    DebugText('IN_AUTH '+sParams);
    s:=ExtractFirstWord(sParams); // IN_AUTH result
    if s='OK' then
    begin
      // Кто-то успешно авторизировался
      s2:=ExtractFirstWord(sParams); // remote addr
      TmpInfo:=GetContactByGUID(sParams);
      ContactConnectedIn(TmpInfo);
    end

    else if s='FAIL' then
    begin
      // Кто-то не авторизировался
    end;
    Event('MGR','REFRESH');
  end

  else if sCmd='EVENT' then
  begin
    sCmd:=ExtractFirstWord(sParams);
    Event(sCmd, sParams);
  end

  else if sCmd='ASK' then
  begin
    // Команда отправки запроса чего-то
    if sParams='' then Exit;
    s:=ExtractFirstWord(sParams);
    s2:=ExtractFirstWord(sParams);
    SendDataMsg(StrToAddr(s), s2, sParams, '');
  end

  else if sCmd='APPROVE' then
  begin
    // APPROVE <GUID>
    // Подтверждает авторизацию линка с указанным GUID
    if sParams='' then Exit;
    TmpInfo:=GetContactByGUID(sParams);
    if Assigned(TmpInfo) then Approve(TmpInfo);
  end

  else if sCmd='GET_INFO' then
  begin
    // GET_INFO <addr>
    // Отправляет на указанный адрес запрос на получение информации
    if sParams='' then Exit;
    RequestInfoByAddr(StrToAddr(sParams));
  end

  else if sCmd='GET_POINTLIST' then
  begin
    // GET_POINTLIST <addr>
    // Отправляет на указанный адрес запрос на получение списка поинтов
    if sParams='' then Exit;
    RequestPointlist(StrToAddr(sParams));
  end

  else if sCmd='ROUTE' then
  begin
    // ROUTE VIA <gate_id> <node_id> [node2_id] ..
    // Добавляет маршруты на указанные узлы через узел gate.
    // Если на узел уже есть маршрут, то он будет заменен
    //
    // ROUTE DEL <node_id>|ALL [node2_id] ...
    // Удаляет маршруты на указанные узлы
    //
    if sParams='' then Exit;
    sCmd:=ExtractFirstWord(sParams);
    if sCmd='VIA' then
    begin
      TraceID:=DateTimeToFileDate(Now());
      s:=ExtractFirstWord(sParams); // node_id
      s2:=ExtractFirstWord(sParams); // next node_id
      while s2<>'' do
      begin
        RoutingTable.AddItem(StrToIntDef(s, 0), StrToIntDef(s2, 0), TraceID);
        s2:=ExtractFirstWord(sParams); // next node_id
      end;
    end

    else if sCmd='DEL' then
    begin
      s:=ExtractFirstWord(sParams); // node_id | ALL
      while s<>'' do
      begin
        if (UpperCase(s)='ALL') then
        begin
          RoutingTable.Clear();
          Break;
        end
        else
          RoutingTable.DelDest(StrToIntDef(s, 0));
        s:=ExtractFirstWord(sParams); // node_id | ALL
      end;

    end;
    Event('MGR','UPDATE ROUTING');
  end;
end;

function TDnmpManager.GetContactByAddr(SomeAddr: TAddr): TDnmpContact;
begin
  Result:=ContactList.GetByAddr(SomeAddr);
  {
  Result:=nil;
  if SameAddr(SomeAddr, MyInfo.Addr) then Result:=MyInfo;

  if not Assigned(Result) then
  begin
    if SomeAddr.Point=0 then Result:=NodeList.GetByAddr(SomeAddr)
    else Result:=PointList.GetByAddr(SomeAddr);
  end;
  }
  if not Assigned(Result) then Result:=UnapprovedList.GetByAddr(SomeAddr);
end;

function TDnmpManager.GetContactByGUID(SomeGUID: string): TDnmpContact;
begin
  Result:=ContactList.GetByGUID(SomeGUID);
  if not Assigned(Result) then Result:=UnapprovedList.GetByGUID(SomeGUID);
end;

function TDnmpManager.Approve(ALinkInfo: TDnmpContact): Boolean;
begin
  Result:=false;
  if not ServerMode then Exit;

  if ALinkInfo.GUID='' then ALinkInfo.GUID:=GenerateGUID();
  if ALinkInfo.SeniorGUID='' then ALinkInfo.SeniorGUID:=MyInfo.GUID;

  if ALinkInfo.Info['addr_type'] <> 'node' then
  begin
    // Выделяем новый номер поинта
    if PointList.HaveItem(ALinkInfo) then Exit;
    ALinkInfo.Addr.Node:=MyInfo.Addr.Node;
    ALinkInfo.Addr.Point:=Self.GetFreePointID();
    // Добавляем в поинтлист, при этом создается новый паспорт
    PointList.AddItem(ALinkInfo);
  end

  else // ALinkInfo.Info['addr_type'] = 'node'
  begin
    { TODO : Нужна проверка подключения к узлу }

    // Выделяем новый номер узла (!!!)
    { TODO : Нужна проверка незанятости номера узла в сегменте }
    if NodeList.HaveItem(ALinkInfo) then Exit;
    ALinkInfo.Addr.Node:=Self.GetFreeNodeID();
    if SameNode(ALinkInfo.Addr, MyInfo.Addr) then Inc(ALinkInfo.Addr.Node);
    ALinkInfo.Addr.Point:=0;
    NodeList.AddItem(ALinkInfo);
    // TODO : Сообщаем другим узлам данные нового узла
    //Mgr.SendLinkInfo(LinkInfo, EmptyAddr());
  end;
  UnapprovedList.Extract(ALinkInfo);
  Result:=True;
  self.Event('MGR','APPROVE');
end;

function TDnmpManager.GetFreePointID(): TPointID;
var
  i: Integer;
  LastPointID: TPointID;
begin
  LastPointID:=0;
  for i:=0 to PointList.Count-1 do
  begin
    if PointList.Items[i].Addr.Point > LastPointID then LastPointID:=PointList.Items[i].Addr.Point;
  end;
  Result:=LastPointID+1;
end;

function TDnmpManager.GetFreeNodeID(): TNodeID;
var
  i: Integer;
  LastNodeID: TNodeID;
begin
  LastNodeID:=0;
  for i:=0 to NodeList.Count-1 do
  begin
    if NodeList.Items[i].Addr.Node > LastNodeID then LastNodeID:=NodeList.Items[i].Addr.Node;
  end;
  Result:=LastNodeID+1;
end;

procedure TDnmpManager.RequestInfoByAddr(Addr: TAddr);
var
  TmpAddr: TAddr;
begin
  if SameAddr(Addr, MyInfo.Addr) then
  begin
    Exit;
  end;

  // node request from his point
  if SameNode(Addr, MyInfo.Addr) and (MyInfo.Addr.Point=0) then
  begin
    TmpAddr.Node:=Addr.Node;
    TmpAddr.Point:=Addr.Point;
  end
  else
  begin
    TmpAddr.Node:=Addr.Node;
    TmpAddr.Point:=0;
  end;
  SendDataMsg(TmpAddr, 'INFO', 'cmd=GINF'+CRLF+'addr='+AddrToStr(Addr), '');
end;

procedure TDnmpManager.RequestPointlist(Addr: TAddr);
var
  TmpAddr: TAddr;
begin
  TmpAddr.Node:=Addr.Node;
  TmpAddr.Point:=0;
  if SameAddr(TmpAddr, MyInfo.Addr) then
  begin
    Exit;
  end;

  SendDataMsg(TmpAddr, 'INFO', 'cmd=GINF'+CRLF+'addr=points', '');
end;

procedure TDnmpManager.RequestContactsByName(AName: string);
var
  sInfo: string;
  msg: TDnmpMsg;
begin
  sInfo:='cmd=CLRQ'+CRLF+'name='+AName+CRLF+'depth=8';
  msg:=TDnmpMsg.Create(MyInfo.Addr, EmptyAddr(), 'INFO', sInfo, '');
  Self.SendBroadcastMsg(msg, 'nodes');
  msg.Free();
end;

function TDnmpManager.MsgDataToStorage(Msg: TDnmpMsg): TDataStorage;
var
  sData: AnsiString;
  TmpSerializer: TDataSerializer;
begin
  Result:=TDataStorage.Create(stUnknown);
  sData:=StreamToStr(Msg.Data);
  TmpSerializer:=Self.Serializer;
  if not TmpSerializer.StorageFromString(Result, sData) then Result:=nil;
end;


end.
