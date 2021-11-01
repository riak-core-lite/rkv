{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/e85975942742a3728226ac22a3415f2355bfc897.tar.gz") {} }:

pkgs.mkShell {
	LOCALE_ARCHIVE_2_27 = if (pkgs.glibcLocales != null) then "${pkgs.glibcLocales}/lib/locale/locale-archive" else "";
	buildInputs = [
		pkgs.glibcLocales
		pkgs.erlang
		pkgs.rebar3
		pkgs.elixir
	];
	shellHook = ''
		export LC_ALL=en_US.UTF-8
	'';
}
