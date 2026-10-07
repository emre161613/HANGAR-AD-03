-- cloud_deneme.max : "Layer:0" cizgisini kapatip yuzey yapar.
-- Sorun: ana spline ACIK (baslangic ve bitis noktasi ust uste ama birlesik degil,
-- arada ~0.16 birim bosluk var). Acik spline'a Extrude kapak (yuzey) olusturmaz.
-- Kullanim: Scripting > Run Script... ile bu dosyayi calistir
-- (ya da once cizgiyi secip calistir).
(
	local obj = getNodeByName "Layer:0"
	if obj == undefined then obj = selection[1]
	if obj == undefined or not (canConvertTo obj SplineShape) then
		messageBox "Cizgi bulunamadi. Cizgiyi secip tekrar calistir."
	else
	(
		convertToSplineShape obj
		local closedCount = 0
		for s = 1 to (numSplines obj) do
		(
			local n = numKnots obj s
			if n > 2 and not (isClosed obj s) then
			(
				local a = getKnotPoint obj s 1
				local b = getKnotPoint obj s n
				if (distance a b) < 1.0 then
				(
					-- son noktanin egrisini (gelen tutamagini) ilk noktaya tasi, sonra son noktayi sil ve kapat
					setKnotType obj s 1 #bezierCorner
					setInVec obj s 1 (getInVec obj s n)
					deleteKnot obj s n
					close obj s
					closedCount += 1
				)
			)
		)
		updateShape obj

		-- Ayri bir yuzey objesi (Editable Poly) olustur; orijinal cizgi duzeltilmis halde kalir
		local yuzey = copy obj
		yuzey.name = "Layer0_Yuzey"
		convertToPoly yuzey

		select yuzey
		format "% spline kapatildi. Yuzey: %  (Layer:0 artik Extrude ile de kapakli cikar)\n" closedCount yuzey.name
	)
)
