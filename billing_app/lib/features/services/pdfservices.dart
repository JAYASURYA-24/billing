import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/bill.dart';
import 'package:open_file/open_file.dart';

Future<void> generateAndOpenPdf(Bill bill) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Bill Number: ${bill.billNumber}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Shop Name: ${bill.shopName}',
              style: pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Status: ${bill.isPaid ? 'Paid' : 'Unpaid'}'),
            pw.SizedBox(height: 12),

            pw.Text(
              'Items:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            ...bill.items.map(
              (item) => pw.Text(
                '${item.name} x${item.quantity} = ${item.total.toStringAsFixed(2)}',
              ),
            ),

            pw.SizedBox(height: 20),
            pw.Divider(),

            pw.Text(
              'Summary:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),

            pw.Text(
              'Previous Due: ₹${bill.previousUnpaid.toStringAsFixed(2)}',
              style: pw.TextStyle(color: PdfColors.red),
            ),
            pw.Text(
              'Current Purchase: ₹${bill.currentPurchaseTotal.toStringAsFixed(2)}',
              style: pw.TextStyle(color: PdfColors.blueGrey),
            ),

            if (bill.paidAmount > 0)
              pw.Text(
                'Paid Now: ₹${bill.paidAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(color: PdfColors.green),
              ),

            if (!bill.isPaid)
              pw.Text(
                'Remaining Unpaid: ₹${bill.remainingUnpaid.toStringAsFixed(2)}',
                style: pw.TextStyle(color: PdfColors.redAccent),
              ),

            pw.SizedBox(height: 8),
            pw.Text(
              'Total Payable: ₹${bill.total.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ],
        );
      },
    ),
  );

  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${bill.billNumber}.pdf');
  await file.writeAsBytes(bytes);

  await OpenFile.open(file.path);
}
