# FS25 Automatic Pipe Light

Skryptowy mod do **Farming Simulator 25** automatyzujący światło rury wyładowczej.

## Działanie

- Gdy pojazd sterowany przez gracza zaczyna rozkładać rurę **w nocy**, mod jednorazowo włącza światło rury.
- Gdy rura zaczyna się składać, mod jednorazowo wyłącza światło rury.
- Jeżeli rura pozostaje rozłożona aż do zapadnięcia nocy, światło również zostanie automatycznie włączone.
- O świcie mod usuwa tylko ten bit światła, który sam wcześniej włączył.
- Mod **nie wymusza stanu świateł w każdej klatce**. Po automatycznej zmianie gracz może normalnie przełączać światła pojazdu.
- Specjalizacja jest dodawana globalnie do wszystkich typów pojazdów mających jednocześnie `Pipe` i `Lights`.
- Obejmuje to zgodne kombajny zbożowe, kombajny do roślin okopowych oraz wozy/przyczepy przeładunkowe.
- Multiplayer jest w tej wersji wyłączony; mod jest przygotowany do gry jednoosobowej.

## Wykrywanie światła rury

Skrypt próbuje kolejno:

1. znaleźć typ światła używany wyłącznie przez lampy znajdujące się na węzłach rury,
2. znaleźć niestandardowy typ światła (4 lub wyższy) umieszczony na rurze,
3. użyć `LightType 4` jako awaryjnego fallbacku, jeżeli pojazd taki typ światła posiada.

Wykrywanie bierze pod uwagę zarówno węzły `Pipe`, jak i węzły uczestniczące w animacji rury. Jest też ostrożny fallback oparty na nazwach węzłów (`pipe`, `unload`) dla nietypowo zbudowanych modów pojazdów.

## Instalacja

Skopiuj plik `FS25_AutoPipeLight.zip` do katalogu:

`Documents/My Games/FarmingSimulator2025/mods/`

Następnie zaznacz mod przy uruchamianiu zapisu gry.

## Diagnostyka

Jeżeli konkretna maszyna nie reaguje prawidłowo, w pliku `scripts/AutoPipeLight.lua` zmień:

```lua
AutoPipeLight.DEBUG = false
```

na:

```lua
AutoPipeLight.DEBUG = true
```

Po uruchomieniu gry w `log.txt` pojawi się wykryta maska światła rury oraz metoda wykrycia.

Jeżeli pojazd ma nietypową konfigurację lamp, można również zmienić stałą:

```lua
AutoPipeLight.FALLBACK_LIGHT_TYPE = 4
```
