unit DBStringTree;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs,
  DB, DBGrids, VirtualTrees, DBPropEdits, TypInfo, ComponentEditors,
  PropEdits;

type

  { TDBTreeDataController }

  PDBTreeDataController = ^TDBTreeDataController;
  TDBTreeDataController=class(TComponentDataLink)
  private
    FDataSet: TDataSet;
    FDataSetName: string;
    FKeyField: TField;
    FKeyFieldName: string;
    FParentField: TField;
    FParentFieldName: string;
    FOnKeyChanged: TFieldNotifyEvent;
    FOnParentChanged: TFieldNotifyEvent;
    procedure SetKeyFieldName(const AValue: string);
    procedure SetParentFieldName(const AValue: string);
    procedure UpdateKeyField;
    procedure UpdateParentField;
  protected
    procedure ActiveChanged; override;
    procedure KeyChanged; virtual;
    procedure ParentChanged; virtual;
  public
    property KeyField: TField read FKeyField;
    property ParentField: TField read FParentField;
    property OnKeyChanged: TFieldNotifyEvent read FOnKeyChanged write FOnKeyChanged;
    property OnParentChanged: TFieldNotifyEvent read FOnParentChanged write FOnParentChanged;
  published
    property DataSource;
    property KeyFieldName : string read FKeyFieldName write SetKeyFieldName;
    property ParentFieldName : string read FParentFieldName write SetParentFieldName;
  end;

  { TDBTreeColumn }

  PDBTreeColumn = ^TDBTreeColumn;
  TDBTreeColumn = class(TVirtualTreeColumn)
  private
    FField: TField;
    FFieldName: string;
    procedure SetFieldName(const AValue: string);
    procedure UpdateField;
    function GetDataSource: TDataSource;
  public
    property Field: TField read FField;
  published
    property DataSource: TDataSource read GetDataSource;
    property FieldName : string read FFieldName write SetFieldName;
  end;

  { TDBNode }

  PDBDataNode = ^TDBDataNode;

  { TDBDataNode }

  TDBDataNode = class
  private
    FKey: Integer;
    FParent: Integer;
    FNode: PVirtualNode;
  public
    constructor Create(AKey: Integer = 0; AParent: Integer = 0; ANode: PVirtualNode = nil);
    property Key: Integer read FKey write FKey;
    property Parent: Integer read FParent write FParent;
    property Node: PVirtualNode read FNode write FNode;
  end;

  { TDBHeader }

  PDBTreeHeader = ^TDBTreeHeader;

  { TDBTreeHeader }

  TDBTreeHeader = class(TVTHeader)
  private
  public
    constructor Create(AOwner: TBaseVirtualTree); override;
  published
    property Options default [hoColumnResize, hoDrag, hoShowSortGlyphs, hoVisible];
  end;

  { TDBStringTree }

  PDBStringTree = ^TDBStringTree;
  TDBStringTree = class(TVirtualStringTree)

  private
    FBuildTree: boolean;
    FDataController: TDBTreeDataController;
    FDataNodes: TList;
    procedure OnRecordChanged(aField:TField);                     //прерывание после изменения записи в DataSet сразу после Post
    procedure OnDataSetChanged(aDataSet: TDataSet);               //прерывание при изменениях в DataSet
    procedure OnDataSetOpen(aDataSet: TDataSet);                  //прерывание при открытии DataSet
    procedure OnDataSetClose(aDataSet: TDataSet);                 //прерывание при закрытии DataSet
    procedure OnEditingChanged(aDataSet: TDataSet);               //прерывание при входе или выходе в/из режима редактирования данных в DataSet
    procedure OnInvalidDataSet(aDataSet: TDataSet);               //прерывание если не правильный DataSet
    procedure OnInvalidDataSource(aDataSet: TDataset);            //прерывание если не правильный DataSource
    procedure OnKeyChanged(aField:TField);
    procedure OnParentChanged(aField:TField);
    procedure OnLayoutChanged(aDataSet: TDataSet);                //прерывание при изменении состава или порядка полей в DataSet
    procedure OnNewDataSet(aDataSet: TDataset);                   //прерывание при подключении к другому DataSet
    procedure OnDataSetScrolled(aDataSet:TDataSet; Distance: Integer);  //прерывание при смене текущей записи в DataSet
    procedure OnDataSourceChanged (aDataSource: TDataSource);
    procedure OnUpdateData(aDataSet: TDataSet);                   //прерывание при записи изменений в БД
    procedure SetDataController(const aValue: TDBTreeDataController);
  protected
    procedure DoGetText(Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var AText: String); override;                //читаем текст ячейки
    function DoFocusChanging(OldNode, NewNode: PVirtualNode; OldColumn, NewColumn: TColumnIndex): Boolean; override;
    procedure DoNewText(Node: PVirtualNode; Column: TColumnIndex; const AText: String); override;
    function GetColumnClass: TVirtualTreeColumnClass; override;
    function GetHeaderClass: TVTHeaderClass; override;

  public
    procedure BuildTree; virtual;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function FindNode(AKey: integer; var AStart: integer): PVirtualNode;
    property DataNodes: TList read FDataNodes;
  published
    property DataController : TDBTreeDataController read FDataController write SetDataController;
  end;

  { TDBStringTreeComponentEditor }

  TDBStringTreeComponentEditor = class(TDBGridComponentEditor)
    public
      procedure ExecuteVerb(Index: Integer); override;
    end;

procedure Register;
function KeyCompare(Item1, Item2: Pointer): Integer;

implementation

procedure Register;
begin
  {$I dbstringtree_icon.lrs}
  RegisterComponents('Virtual Controls',[TDBStringTree]);

  RegisterComponentEditor(TDBStringTree,TDBStringTreeComponentEditor);

  RegisterPropertyEditor(TypeInfo(string), TDBTreeDataController, 'KeyFieldName', TFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TDBTreeDataController, 'ParentFieldName', TFieldProperty);
  RegisterPropertyEditor(TypeInfo(string), TDBTreeColumn, 'FieldName', TFieldProperty);
end;

function KeyCompare(Item1, Item2: Pointer): Integer;
begin
  if TDBDataNode(Item1).Key > TDBDataNode(Item2).Key
    then Result := 1
    else if TDBDataNode(Item1).Key = TDBDataNode(Item2).Key
           then Result := 0
           else Result := -1;
end;

{ TDBStringTreeComponentEditor }

procedure TDBStringTreeComponentEditor.ExecuteVerb(Index: Integer);
var
  Hook: TPropertyEditorHook;
  DBStringTree: TDBStringTree;
begin
  DBStringTree := GetComponent as TDBStringTree;
  GetHook(Hook);
  EditCollection(DBStringTree, DBStringTree.Header.Columns, 'Columns');
  if Assigned(Hook) then Hook.Modified(Self);
end;

{ TDBStringTree }
function TDBStringTree.DoFocusChanging(OldNode, NewNode: PVirtualNode;
  OldColumn, NewColumn: TColumnIndex): Boolean;
begin

  Result:=inherited DoFocusChanging(OldNode, NewNode, OldColumn, NewColumn);
  if Result and
     Assigned(NewNode) then
    begin
      FBuildTree:=true;
      Result:=DataController.FDataSet.Locate(FDataController.FKeyFieldName,
                                           TDBDataNode(GetNodeData(NewNode)^).Key,[]);
      FBuildTree:=false;
    end;
end;

procedure TDBStringTree.DoNewText(Node: PVirtualNode; Column: TColumnIndex;
  const AText: String);
begin
  inherited DoNewText(Node, Column, AText);
  if DataController.DataSet.Active and
     (DataController.DataSet.RecordCount>0) then
    begin
      FBuildTree:=true;
      DataController.DataSet.DisableControls;
      DataController.DataSet.Edit;
      TDBTreeColumn(Header.Columns[Column]).FField.Value:=AText;
      DataController.DataSet.Post;
      DataController.DataSet.EnableControls;
      FBuildTree:=false;
    end;
end;

procedure TDBStringTree.DoGetText(Node: PVirtualNode; Column: TColumnIndex;
  TextType: TVSTTextType; var AText: String);
var t: variant;
begin
  if (not Assigned(Node)) or (Column < 0) then exit;
    if Assigned(FDataController.DataSet) and
                FDataController.DataSet.Active and
                Assigned(TDBTreeColumn(Header.Columns.Items[Column]).FField) and
                Assigned(GetNodeData(Node)) then
      if TDBTreeColumn(Header.Columns.Items[Column]).FField.DataType = ftBlob
        then AText:='(blob)'
        else begin
               t := FDataController.DataSet.Lookup(FDataController.FKeyFieldName,
                      TDBDataNode(GetNodeData(Node)^).Key,
                      TDBTreeColumn(Header.Columns.Items[Column]).FFieldName);
               if t=Null
                 then AText:= ''
                 else AText:= t;
             end;
  inherited DoGetText(Node, Column, TextType, AText); // обработка прерывания OnGetText
end;

procedure TDBStringTree.OnRecordChanged(AField: TField);
begin
  FBuildTree:=FBuildTree;
end;

procedure TDBStringTree.OnDataSetChanged(aDataSet: TDataSet);
begin
  BuildTree;
end;

procedure TDBStringTree.OnDataSetOpen(aDataSet: TDataSet);
begin
  BuildTree;
end;

procedure TDBStringTree.OnDataSetClose(aDataSet: TDataSet);
begin
  Clear;  //удалить все узлы из дерева
  FDataNodes.Clear;        //удалить данные узлов
end;

procedure TDBStringTree.OnEditingChanged(aDataSet: TDataSet);
begin
  FBuildTree:=FBuildTree;
end;

procedure TDBStringTree.OnInvalidDataSet(aDataSet: TDataSet);
begin
  Clear;  //удалить все узлы из дерева
  FDataNodes.Clear;        //удалить данные узлов
end;

procedure TDBStringTree.OnInvalidDataSource(aDataSet: TDataset);
begin
  Clear;  //удалить все узлы из дерева
  FDataNodes.Clear;        //удалить данные узлов
end;

procedure TDBStringTree.OnKeyChanged(AField: TField);
begin
  BuildTree;
end;

procedure TDBStringTree.OnParentChanged(AField: TField);
begin
  BuildTree;
end;

procedure TDBStringTree.OnLayoutChanged(aDataSet: TDataSet);
begin
  BuildTree;
end;

procedure TDBStringTree.OnNewDataSet(aDataSet: TDataset);
var i: Integer;
begin
  if Header.Columns.Count>0 then
  begin
    for i:= 0 to Header.Columns.Count-1 do
      TDBTreeColumn(Header.Columns[i]).UpdateField;
    BuildTree;
  end;
end;

procedure TDBStringTree.OnDataSetScrolled(aDataSet: TDataSet; Distance: Integer);
begin

  FBuildTree:=true;
  BeginUpdate;
  FocusedNode :=TDBDataNode(FDataNodes.Items[
                            DataNodes.IndexOf(TDBDataNode(
                            GetNodeData(FocusedNode)^))+Distance]).FNode;
  Selected[FocusedNode]:=true;
  EndUpdate;
  FBuildTree:=false;

end;

procedure TDBStringTree.OnDataSourceChanged(ADataSource: TDataSource);
var i: Integer;
begin
  if Header.Columns.Count>0 then
  begin
    for i:= 0 to Header.Columns.Count-1 do
      TDBTreeColumn(Header.Columns[i]).UpdateField;
    BuildTree;
  end;
end;

procedure TDBStringTree.SetDataController(const AValue: TDBTreeDataController);
begin
    FDataController.Assign(AValue);

end;

procedure TDBStringTree.OnUpdateData(aDataSet: TDataSet);
begin
end;

function TDBStringTree.GetColumnClass: TVirtualTreeColumnClass;
begin
  Result := TDBTreeColumn;
end;

function TDBStringTree.GetHeaderClass: TVTHeaderClass;
begin
  Result:=TDBTreeHeader;
end;

procedure TDBStringTree.BuildTree;
var
  i,s: Integer;
  P: TDBDataNode;
  N: PVirtualNode;
begin

  with DataController do
    if (FBuildTree) or            //если идет построение дерева или
       (DataSet = nil) or           //нет таблицы или
       (not DataSet.Active) or      //таблица не открыта или
       (DataSet.RecordCount<=0) or  //в таблице нет записей или
       (FKeyField = nil)            //ключевое поле не определено
      then exit;                    //тогда выйти
  FBuildTree:=true;       //установить флаг построения дерева
  BeginUpdate;            //запретить обновление отображения дерева
  Clear;                  //удалить все узлы дерева
  FDataNodes.Clear;       //удалить узлы данных
  with DataController do
    begin
      DataSet.DisableControls;               //отключить данные от контрола
      DataSet.First;                         //встать на первую запись таблицы
      for i:=1 to DataSet.RecordCount do     //для всех записей таблицы
      begin
        P:=TDBDataNode.Create(FKeyField.AsInteger); //создать узел данных с ключевым полем
        if FParentField <> nil                      //если поле родителя определено
           then P.FParent:=FParentField.AsInteger;    //то добавим в узел данных
        P.Node:=AddChild(nil,P);                    //создать узел дерева, указатель на него пишем в узел данных
        FDataNodes.Add(P);                          //добавим узел данных в дерево список данных
        DataSet.Next;                          //следующий
      end;
      DataSet.First;                         //встать на первую запись таблицы
      DataSet.EnableControls;                //подключить данные к контролу
      FDataNodes.Sort(@KeyCompare);          //Сортируем данные по ключевому полю
      s:=0;
      if FParentField <> nil then            //если есть ParentField
        for i:=0 to FDataNodes.Count-1 do      //делаем для всех узлов
          MoveTo(TDBDataNode(FDataNodes.Items[i]).FNode,
                 FindNode(TDBDataNode(FDataNodes.Items[i]).FParent, s),
                 amAddChildLast, False );
    end;
  EndUpdate;
  FBuildTree:=false;

end;


{Поиск узла по ключевому полю:
   AKey - значение ключа;
   AStart - начальная позиция поиска
  возвращает указатель на узел дерева }

function TDBStringTree.FindNode(AKey: integer; var AStart: integer): PVirtualNode;
var
  verh: integer; { верхняя граница поиска }
  niz: integer; { нижняя граница поиска }
  found: boolean; { TRUE — совпадение образца с элементом массива }
begin
  if FDataNodes.Count <= 0 then //если нет узлов данных
  begin
    AStart:=-1;       //позицию поиска установить -1
    Result:=RootNode; //вернуть корень
    exit;             //выйти
  end;
  if AStart > FDataNodes.Count - 1      //если позиция поиска больше индекса последнего узла
    then AStart := FDataNodes.Count-1;  //установить позицию поиска в индекс последнего узла
  if AStart < 0 then AStart := 0;     //если позиция поиска отрицательное то установить в 0

  if AKey = TDBDataNode(FDataNodes.Items[AStart]).FKey        //если искомое равно текущему
    then found := TRUE                                          //то установить флаг "найдено"
    else begin                                                  //иначе
           found := FALSE;                                        //снять флаг "найдено"
           if AKey < TDBDataNode(FDataNodes.Items[AStart]).FKey   //если искомое меньше текущего
             then begin                                             //то
                    verh := 0;                                        //начало ставим в 0
                    niz := AStart - 1;                                //конечную позицию сдвигаем на 1 выше текущей
                  end
             else begin                                              //иначе если больше
                    verh := AStart + 1;                                //начальную позицию сдвигаем на 1 ниже текущей
                    niz := FDataNodes.Count-1;                         //конечную позицию ставим на последий узел
                  end;
           while (verh <= niz) and (not found) do                      //пока верх меньше или равно низ и нет флага "найдено"
           begin
             AStart := ((niz - verh) div 2) + verh;                   //текущая позиция в середину диапазона
             if AKey = TDBDataNode(FDataNodes.Items[AStart]).FKey        //если искомое равно текущему
               then found := TRUE                                          //то установить флаг "найдено"
               else if AKey < TDBDataNode(FDataNodes.Items[AStart]).FKey   //иначе если искомое меньше текущего
                      then niz := AStart - 1                                 //конечную позицию сдвигаем на 1 выше текущей
                      else verh := AStart + 1;                               //иначе начальную позицию сдвигаем на 1 ниже текущей
           end;
         end;
  if found then Result:=TDBDataNode(FDataNodes.Items[AStart]).FNode //если найдено, вернуть узел
           else Result:=RootNode;                                   //иначе вернуть корень
end;


constructor TDBStringTree.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBuildTree:=false;
  NodeDataSize := SizeOf(TDBDataNode);
  //ControlStyle := ControlStyle - [csOwnedChildrenNotSelectable];
  FDataController := TDBTreeDataController.Create;
  FDataNodes:=TList.Create;
  FDataController.OnRecordChanged:=@OnRecordChanged;
  FDataController.OnDatasetChanged:=@OnDataSetChanged;
  FDataController.OnDataSetOpen:=@OnDataSetOpen;
  FDataController.OnDataSetClose:=@OnDataSetClose;
  FDataController.OnNewDataSet:=@OnNewDataSet;
  FDataController.OnInvalidDataSet:=@OnInvalidDataset;
  FDataController.OnInvalidDataSource:=@OnInvalidDataSource;
  FDataController.OnKeyChanged:=@OnKeyChanged;
  FDataController.OnParentChanged:=@OnParentChanged;
  FDataController.OnDataSetScrolled:=@OnDataSetScrolled;
  FDataController.OnLayoutChanged:=@OnLayoutChanged;
  FDataController.OnEditingChanged:=@OnEditingChanged;
  FDataController.OnUpdateData:=@OnUpdateData;
end;

destructor TDBStringTree.Destroy;
begin
  FDataController.OnRecordChanged:=nil;
  FDataController.OnDatasetChanged:=nil;
  FDataController.OnDataSetOpen:=nil;
  FDataController.OnDataSetClose:=nil;
  FDataController.OnNewDataSet:=nil;
  FDataController.OnInvalidDataSet:=nil;
  FDataController.OnInvalidDataSource:=nil;
  FDataController.OnKeyChanged:=nil;
  FDataController.OnParentChanged:=nil;
  FDataController.OnDataSetScrolled:=nil;
  FDataController.OnLayoutChanged:=nil;
  FDataController.OnEditingChanged:=nil;
  FDataController.OnUpdateData:=nil;
  FDataNodes.Free;
  FDataController.Free;
  inherited Destroy;
end;


{ TDBTreeHeader }

constructor TDBTreeHeader.Create(AOwner: TBaseVirtualTree);
begin
  inherited Create(AOwner);
  Options := [hoColumnResize, hoDrag, hoShowSortGlyphs, hoVisible];
end;

{ TDBDataNode }

constructor TDBDataNode.Create(AKey: Integer; AParent: Integer;
  ANode: PVirtualNode);
begin
  FKey:=AKey;
  FParent:=AParent;
  FNode:=ANode;
end;

{ TDBTreeColumn }

procedure TDBTreeColumn.SetFieldName(const AValue: string);
begin
  if FFieldName <> AValue then
  begin
    FFieldName := AValue;
    UpdateField;
    if Text='' then Text:=AValue;
  end;
end;

procedure TDBTreeColumn.UpdateField;
begin
  with TDBStringTree(TVirtualTreeColumns(Collection).Header.Treeview) do
    if DataController.Active and (FFieldName <> '')
      then begin
             FField := DataController.DataSet.FieldByName(FFieldName);
             Repaint;
           end
      else begin
             FField := nil;
             Repaint;
           end;
end;

function TDBTreeColumn.GetDataSource: TDataSource;
begin
  Result:=TDBStringTree(TVirtualTreeColumns(Collection).Header.Treeview).DataController.DataSource;
end;

{ TDBTreeDataController }

procedure TDBTreeDataController.ActiveChanged;
begin
  if Active
    then begin
           FDataSet := DataSet;
           if DataSetName <> fDataSetName
             then begin
                    fDataSetName := DataSetName;
                    UpdateKeyField;
                    UpdateParentField;
                    if Assigned(OnNewDataSet) then OnNewDataSet(DataSet);
                  end
             else if Assigned(OnDataSetOpen) then OnDataSetOpen(DataSet);
         end
    else begin
           BufferCount := 0;
           if (DataSource = nil)
             then begin
                    if Assigned(OnInvalidDataSource) then OnInvalidDataSource(fDataSet);
                    fDataSet := nil;
                    fDataSetName := '[???]';
                  end
             else begin
                    if (DataSet=nil)or(csDestroying in DataSet.ComponentState)
                      then begin
                             if Assigned(OnInvalidDataSet) then OnInvalidDataSet(fDataSet);
                             fDataSet := nil;
                             fDataSetName := '[???]';
                           end
                      else begin
                             if Assigned(OnDataSetClose) then OnDataSetClose(DataSet);
                             if DataSet <> nil then FDataSetName := DataSetName;
                           end;
                  end;
         end;
end;

procedure TDBTreeDataController.SetKeyFieldName(const AValue: string);
begin
  if FKeyFieldName <> AValue then
  begin
    FKeyFieldName := AValue;
    UpdateKeyField;
  end;
end;

procedure TDBTreeDataController.SetParentFieldName(const AValue: string);
begin
  if FParentFieldName <> AValue then
  begin
    FParentFieldName := AValue;
    UpdateParentField;
  end;
end;

procedure TDBTreeDataController.UpdateKeyField;
begin
  if Active and
     DataSet.Active and
     (FKeyFieldName <> '')
    then FKeyField := DataSet.FieldByName(FKeyFieldName)
    else FKeyField := nil;
  KeyChanged;
end;

procedure TDBTreeDataController.UpdateParentField;
begin
  if Active and
     DataSet.Active and
     (FParentFieldName <> '')
    then FParentField := DataSet.FieldByName(FParentFieldName)
    else FParentField := nil;
  ParentChanged;
end;

procedure TDBTreeDataController.KeyChanged;
begin
  if Assigned(FOnKeyChanged) then
    FOnKeyChanged(FKeyField);
end;

procedure TDBTreeDataController.ParentChanged;
begin
  if Assigned(FOnParentChanged) then
    FOnParentChanged(FParentField);
end;

end.
