unit UnitMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  GLS.Cadencer, GLS.SceneViewer, Vcl.Imaging.jpeg, GLS.BaseClasses,
  GLS.Scene, GLS.CameraController, GLS.Objects, GLS.Coordinates, GLS.Collision,
  GLS.DCE, GLS.Color, GLS.FireFX, GLS.VectorTypes, GLS.GeomObjects, Vcl.ExtCtrls;

const
  PosX = 1.25; // Кратность по горизонтали
  PosY = 1.35; // Кратность по вертикали
  Mult = 10.0; // Множитель для движения (скорость)
  MaxX = 21.0; // Пределы игрового поля X/Y
  MaxY = 15.4;
  SRad = 1.25; // Радиус сферы элемента
  GRad = 0.25; // Радиус глаза
  DLen = 1.50; // Расстояние между точками (сферами)
  PosG: TVector3f = (X: 0.5; Y: 0.25; Z: 0.95); // Положение глаз
  ColHeadA: TColorVector = (X: 1; Y: 1; Z: 0; W: 1);// = clrYellow;
  ColHeadD: TColorVector = (X: 0.6; Y: 0.8; Z: 0.196078; W: 1);// = clrYellowGreen;
  ColBodyA: TColorVector = (X: 0; Y: 0.5; Z: 0; W: 1);// = clrGreen;
  ColBodyD: TColorVector = (X: 0.576471; Y: 0.858824; Z: 0.439216; W: 1);// = clrGreenYellow;
  ColGlasA: TColorVector = (X: 0.196078; Y: 0.196078; Z: 0.8; W: 1);// = clrMediumBlue;
  ColGlasD: TColorVector = (X: 0.137255; Y: 0.137255; Z: 0.556863; W: 1);// = clrNavy;

type
  TDirMove = (dmNone, dmUp, dmDown, dmLeft, dmRight);

  TCorList = class;
  TCorList = class(TObject)
  private
    px, py: Single; // Координаты участка (центр)
    dx, dy: Single; // Координаты куда движемся
    obj: TGLSphere; // Непосредстенный шар (кусок тела) змеи (интерсепт только тут)
    DirMove: TDirMove; // Куда будет двигаться элемент (голову направляем клавишами,
    // остальное определяем математически
    //function IsNeedMove: Boolean;
  public
    NextItem: TCorList;
    num: Integer;
    constructor Create(_px, _py: Single; _num: Integer);
    destructor Destroy; override;
    procedure MoveTo(_dx, _dy: Single);
  end;

  TCorFirst = class(TCorList)
  private
    glas1, glas2: TGLSphere; // глаза змейки
  public
    constructor Create(_px, _py: Single);
    destructor Destroy; override;
  end;

  TSnakeObj = class(TObject)
  private
    DirMove: TDirMove;
    SnakeHead: TCorFirst;
    SnakeBody: TCorList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure MoveSnake(_dir: TDirMove; _delta: Double);
    function IsCanMove: Boolean;
  end;

  TfrmMain = class(TForm)
    _gls: TGLScene;
    _Scena: TGLSceneViewer;
    _glc: TGLCadencer;
    _GLCameraMain: TGLCamera;
    _GLDumCube: TGLDummyCube;
    _glsFon: TGLSprite;
    _glm: TGLDCEManager;
    GLLight: TGLLightSource;
    GLSphereTemp: TGLSphere;
    GLSphere2: TGLSphere;
    GLSphere3: TGLSphere;
    timAddEat: TTimer;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure _glcProgress(Sender: TObject; const DeltaTime, NewTime: Double);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure _glmCollision(Sender: TObject;
        object1, object2: TGLBaseSceneObject; CollisionInfo: TDCECollision);
    procedure FormDestroy(Sender: TObject);
    procedure WM_StopGame(var msg: TMessage); message WM_USER; // Остановить игру
    procedure timAddEatTimer(Sender: TObject);
    procedure Timer1Timer(Sender: TObject); // Нашли что схесть
  private
    DirMove: TDirMove;
    SnakeBo: TSnakeObj;
  public
    Total: Cardinal;
    EatList: array [-5..-1] of TGLCapsule; // Массив пилюль
    procedure StopGame;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
var
  gl: TGLSphere;
  o: TGLBCollision;
  p: TCorList;
  i: Integer;
begin
  // Инициализация
  Constraints.MinHeight := Height;
  Constraints.MaxHeight := Height;
  Constraints.MinWidth := Width;
  Constraints.MaxWidth := Width;
  SnakeBo := TSnakeObj.Create;
  DirMove := dmNone;
  _glc.Enabled := True;
  Total := 0;
  for i := Low(EatList) to High(EatList) do EatList[i] := nil;
  timAddEat.Interval := 1000; // Первый фрагмент
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
var
  o: TCorList;
  j: Integer;
begin
  // Разрушить объекты
  _glc.Enabled := False;
  timAddEat.Enabled := False;
  SnakeBo.Free;
  for j := Low(EatList) to High(EatList) do
    if Assigned(EatList[j]) then try
      EatList[j].Free;
    except
    end;
end;

procedure TfrmMain.FormKeyPress(Sender: TObject; var Key: Char);
var
  k: Char;
  o: TGLSphere;
  b: TGLDCEDynamic;
  p: TCorList;
begin
  // Меняем направление
  k := UpCase(Key);
  case k of
    'W', 'Ц':
      if DirMove = dmDown then
        PostMessage(Handle, WM_USER, 0, 0)
      else
        DirMove := dmUp;

    'S', 'Ы':
      if DirMove = dmUp then
        PostMessage(Handle, WM_USER, 0, 0)
      else
        DirMove := dmDown;

    'A', 'Ф':
      if DirMove  = dmRight then
        PostMessage(Handle, WM_USER, 0, 0)
      else
        DirMove := dmLeft;

    'D', 'А':
      if DirMove  = dmLeft then
        PostMessage(Handle, WM_USER, 0, 0)
      else
        DirMove := dmRight;

    {
    'N': begin
      p := SnakeBo.SnakeHead;
      while Assigned(p.NextItem) do p := p.NextItem;
      p.NextItem := TCorList.Create(p.px, p.py, p.num + 1);
      if not Assigned(SnakeBo.SnakeBody) then
        SnakeBo.SnakeBody := p.NextItem;
    end;
    }
  end;
  timAddEat.Enabled := True; // Запуск после нажатия
end;

procedure TfrmMain.StopGame;
begin
  // Игра окончена
  _glc.Enabled := False;
  ShowMessage('ИГРА ОКОНЧЕНА!' + sLineBreak +
      'Набрано очков: ' + IntToStr(Total));
  FormDestroy(nil);
  FormCreate(nil);
end;

procedure TfrmMain.timAddEatTimer(Sender: TObject);
var
  x, y, dist: Single;
  dx, dy: Integer;
  j: Integer;
  p: TCorList;
  v: TVector4f;
  b: TGLDCEDynamic;
begin
  // Добавляем еду каждые 3 секунды
  timAddEat.Enabled := False;
  timAddEat.Interval := 3000;
  // Поиск свободной ячейки
  try
    j := Low(EatList);
    while Assigned(EatList[j]) do begin
      Inc(j);
      if j > High(EatList) then Abort;
    end;
    // Найти координаты для точки
    Randomize;
    dx := Trunc(MaxX);
    x := dx - Random(dx shl 1);
    while x - PosX <= -MaxX do x := x + PosX;
    while x + PosX >= MaxX do x := x - PosX;
    dy := Trunc(MaxY);
    y := dy - Random(dy shl 1);
    while y - PosY <= -MaxY do y := y + PosY;
    while y + PosY >= MaxY do y := y - PosY;
    // Проверить на расстояние до червяка
    p := SnakeBo.SnakeHead;
    while Assigned(p) do begin
      dist := Sqrt(Sqr(x - p.px) + Sqr(y - p.py));
      if dist < SRad * 3 then begin
        // Слишком близко
        timAddEat.Interval := 500; // Уменьшаем время попытки
        Abort;
      end;
      p := p.NextItem;
    end;
    // Создать пилюлю
    EatList[j] := TGLCapsule.Create(frmMain._GLDumCube);
    EatList[j].Parent := frmMain._GLDumCube;
    EatList[j].Radius := SRad / 3;
    EatList[j].Height := SRad / 1.5;
    EatList[j].Material.FrontProperties.Ambient.Color := clrRed;
    v.W := 1; // Цвет дифузии случайным образом
    v.X := Random(10000) / 10000;
    v.Y := Random(10000) / 10000;
    v.Z := Random(10000) / 10000;
    EatList[j].Material.FrontProperties.Diffuse.Color := v;
    EatList[j].Tag := j;
    EatList[j].Position.X := x;
    EatList[j].Position.Y := y;
    EatList[j].TurnAngle := 45;
    // Обработка колизии
    if EatList[j].Behaviours.CanAdd(TGLDCEDynamic) then begin
      b := TGLDCEDynamic.Create(nil);
      b.Manager := _glm;
      EatList[j].Behaviours.Add(b);
    end;
  except
  end;
  timAddEat.Enabled := True;
end;

procedure TfrmMain.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  ShowMessage('Игру сделал для ребёнка по её просьбе 02.01.2022г.' + sLineBreak +
      'Делать было вечером, делать было нечего.' + sLineBreak +
      'Управление клавишами WASD, пауза не предусмотрена, наворотов нет. Игра ' +
      'прекращается: при движении в противоположную сторону, удар в стену, ' +
      'укусил свой хвост.');
end;

procedure TfrmMain.WM_StopGame(var msg: TMessage);
var
  VMsg: TMsg;
begin
  while PeekMessage(VMsg, Handle, WM_USER, WM_USER, PM_REMOVE or PM_NOYIELD) do;
  StopGame;
end;

procedure TfrmMain._glmCollision(Sender: TObject; object1,
  object2: TGLBaseSceneObject; CollisionInfo: TDCECollision);
var
  sn1, sn2: TGLSphere;
  j, m: Integer;
  o: TGLCapsule;
  p: TCorList;
begin
  if ((object1.Tag = 1) and (object2.Tag < 0))
      or ((object2.Tag = 1) and (object1.Tag < 0)) then begin
    // Нашёл еду
    o := nil;
    j := object1.Tag;
    if j = 1 then j := object2.Tag;
    if object1.ClassType = TGLCapsule then o := object1 as TGLCapsule;
    if object2.ClassType = TGLCapsule then o := object2 as TGLCapsule;
    m := 0;
    if Assigned(o) then try
      with o.Material.FrontProperties.Diffuse.Color do m := Round(X + Y + Z);
    except
    end;
    if m <= 0 then m := 1;
    Inc(Total, m);
    FreeAndNil(EatList[j]);
    // Удленить червя
    p := SnakeBo.SnakeHead;
    while Assigned(p.NextItem) do p := p.NextItem;
    p.NextItem := TCorList.Create(p.px, p.py, p.num + 1);
    if not Assigned(SnakeBo.SnakeBody) then
    SnakeBo.SnakeBody := p.NextItem;
  end else if (Abs(object1.Tag - object2.Tag) > 3) and
      ((object1.Tag = 1) or (object2.Tag = 1)) then begin
    // Врезался в тело своё
    //Caption := IntToStr(object1.Tag) + ' + ' + IntToStr(object2.Tag);
    PostMessage(frmMain.Handle, WM_USER, 0, 0);
  end;
end;

procedure TfrmMain._glcProgress(Sender: TObject; const DeltaTime,
  NewTime: Double);
var
  d: Double;
  o: TCorList;
  j: Integer;
begin
  d := DeltaTime * Mult;
  SnakeBo.MoveSnake(DirMove, d);
  for j := Low(EatList) to High(EatList) do
    if Assigned(EatList[j]) then try
      EatList[j].Pitch(d * SRad * 5);
    except
    end;
end;

{ TCorList }

constructor TCorList.Create(_px, _py: Single; _num: Integer);
var
  b: TGLDCEDynamic;
begin
  inherited Create;
  // Инициализация
  NextItem := nil;
  num := _num;
  // Создаём очередной элемент тела
  px := _px;
  dx := px;
  py := _py;
  dy := py;

  // Шарик
  obj := TGLSphere.Create(frmMain._GLDumCube);
  obj.Parent := frmMain._GLDumCube;
  obj.Radius := SRad;
  obj.Material.FrontProperties.Ambient.Color := ColBodyA;
  obj.Material.FrontProperties.Diffuse.Color := ColBodyD;
  obj.Tag := num;
  obj.Position.X := px;
  obj.Position.Y := py;

  // Обработка колизии
  if obj.Behaviours.CanAdd(TGLDCEDynamic) then begin
    b := TGLDCEDynamic.Create(nil);
    b.Manager := frmMain._glm;
    obj.Behaviours.Add(b);
  end;
end;

destructor TCorList.Destroy;
begin
  obj.Free;
  if Assigned(NextItem) then try
    NextItem.Free;
  except
  end;
  inherited;
end;

procedure TCorList.MoveTo(_dx, _dy: Single);
begin
  // Установить конечные точки для перемещения
  dx := _dx;
  dy := _dy;
  obj.Position.X := dx;
  obj.Position.Y := dy;
  if Assigned(NextItem) then try
    // Последующие занимают место текущего
    NextItem.MoveTo(px, py);
  except
  end;
  px := obj.Position.X;
  py := obj.Position.Y;
end;

{ TSnakeObj }

constructor TSnakeObj.Create;
begin
  inherited;
  // Инициализация (создание змеи)
  DirMove := dmNone;
  SnakeHead := TCorFirst.Create(0, 0);
  SnakeBody := nil;
end;

destructor TSnakeObj.Destroy;
begin
  SnakeHead.Free; // Тело привязано к голове через NextItem
  inherited;
end;

function TSnakeObj.IsCanMove: Boolean;
var
  x, y: Single;
begin
  // Проверка на возможность движения хвоста и поворот червя
  Result := True;
  if not Assigned(SnakeBody) then Exit; // Нет тела ещё
  x := Abs(SnakeHead.obj.Position.X - SnakeBody.obj.Position.X);
  y := Abs(SnakeHead.obj.Position.Y - SnakeBody.obj.Position.Y);
  if (x >= DLen) or (y >= DLen) then Exit; // Достаточно для движения
  Result := False; // Нет варианта для разрешения
end;

procedure TSnakeObj.MoveSnake(_dir: TDirMove; _delta: Double);
var
  col: TGLCoordinates3;
begin
  // Выполнить изменение направления движения
  DirMove := _dir;
  col := SnakeHead.obj.Position;
  case DirMove of
    dmUp: begin
      col.Y := col.Y + _delta;
      SnakeHead.obj.RollAngle := 0;
    end;

    dmDown: begin
      col.Y := col.Y - _delta;
      SnakeHead.obj.RollAngle := 180;
    end;

    dmLeft: begin
      col.X := col.X - _delta;
      SnakeHead.obj.RollAngle := 90;
    end;

    dmRight: begin
      col.X := col.X + _delta;
      SnakeHead.obj.RollAngle := -90;
    end;
  end;
  if DirMove <> dmNone then begin
    if col.Y < -MaxY then begin
      col.Y := -MaxY;
      PostMessage(frmMain.Handle, WM_USER, 0, 0);
    end;
    if col.Y > MaxY then begin
      col.Y := MaxY;
      PostMessage(frmMain.Handle, WM_USER, 0, 0);
    end;
    if col.X < -MaxX then begin
      col.X := -MaxX;
      PostMessage(frmMain.Handle, WM_USER, 0, 0);
    end;
    if col.X > MaxX then begin
      col.X := MaxX;
      PostMessage(frmMain.Handle, WM_USER, 0, 0);
    end;
  end;
  if Assigned(SnakeBody) and IsCanMove then
    SnakeBody.MoveTo(SnakeHead.px, SnakeHead.py);
  SnakeHead.px := col.X;
  SnakeHead.py := col.Y;
  SnakeHead.dx := col.X;
  SnakeHead.dy := col.Y;
end;

{ TCorFirst }

constructor TCorFirst.Create(_px, _py: Single);
begin
  inherited Create(_px, py, 1); // Голова с номером 1
  // Добавляем глаза
  glas1 := TGLSphere.CreateAsChild(obj);
  glas1.Parent := obj;
  glas2 := TGLSphere.CreateAsChild(obj);
  glas2.Parent := obj;
  glas1.Radius := GRad;
  glas2.Radius := GRad;
  glas1.Position.AsAffineVector := PosG;
  glas2.Position.AsAffineVector := PosG;
  glas2.Position.X := -1 * glas2.Position.X;
  glas1.Material.FrontProperties.Ambient.Color := ColGlasA;
  glas2.Material.FrontProperties.Ambient.Color := ColGlasA;
  glas1.Material.FrontProperties.Diffuse.Color := ColGlasD;
  glas2.Material.FrontProperties.Diffuse.Color := ColGlasD;
  // Красим голову
  obj.Material.FrontProperties.Ambient.Color := ColHeadA;
  obj.Material.FrontProperties.Diffuse.Color := ColHeadD;
end;

destructor TCorFirst.Destroy;
begin
  glas1.Free;
  glas2.Free;
  inherited;
end;

end.
